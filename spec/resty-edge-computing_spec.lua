package.path = package.path .. ";spec/?.lua"

local edge_computing = require "resty-edge-computing"
local fake_redis
local redis_smembers_resp = {}
local redis_get_resp = "0"
local ngx_phase = nil

_G.ngx = {
  get_phase=function() return ngx_phase end,
  null="NULL",
  time=function() return 0 end,
  worker={
    pid=function() return 0 end,
    id=function() return 0 end,
  },
  log=function(_, msg) print(msg) end,
  timer={
    -- luacheck: no unused args
    every=function(interval, func) return "Running in background" end
  },
  exit=function(code) print(code) end,
  say=function(code) print(code) end,
}

before_each(function()
    fake_redis = {}
    stub(fake_redis, "smembers")
    stub(fake_redis, "get")
    fake_redis.smembers = function(_)
      return redis_smembers_resp, nil
    end
    fake_redis.get = function(_)
      return redis_get_resp, nil
    end
    redis_smembers_resp = {}
    redis_get_resp = "0"
    ngx_phase = "rewrite"
    -- simulating initial state
    edge_computing.ready = false
    edge_computing.redis_client = nil
    edge_computing.interval = 20
end)

describe("Resty Edge Computing", function()
  it("has sensible default", function()
    assert.same(edge_computing.ready, false)
    assert.same(edge_computing.interval, 20)
  end)

  describe("#start", function()
    it("requires a redis client", function()
      local resp, err = edge_computing.start()

      assert.is_nil(resp)
      assert.is_not_nil(err)
    end)

    it("doesn't runs on other phase except rewrite", function()
      for _, phase in ipairs(edge_computing.phases) do
        if phase ~= "rewrite" then
          ngx_phase = phase
          local resp, err = edge_computing.start()

          assert.is_nil(resp)
          assert.is_not_nil(err)
        end
      end
    end)

    it("can accept optional interval", function()
      local resp, err = edge_computing.start(fake_redis, 42)

      assert.is_nil(err)
      assert.is_not_nil(resp)
      assert.is_not.same(edge_computing.interval, 20)
      assert.same(edge_computing.interval, 42)
    end)

    it("runs a single time", function()
      stub(ngx.timer, "every")
      local resp, err = edge_computing.start(fake_redis)

      assert.is_nil(err)
      assert.is_not_nil(resp)
      assert.stub(ngx.timer.every).was.called(1)

      -- luacheck: ignore
      ngx.timer.every:revert()
    end)

    it("updates in the first call", function()
      stub(edge_computing, "update")
      local resp, err = edge_computing.start(fake_redis)

      assert.is_nil(err)
      assert.is_not_nil(resp)
      assert.stub(edge_computing.update).was.called(1)

      -- luacheck: ignore
      edge_computing.update:revert()
    end)
  end)

  describe("#update", function()
    before_each(function()
      -- we pressume readiness
      edge_computing.ready = true
      -- redis_client
      edge_computing.redis_client = fake_redis
      -- empty cus
      edge_computing.initialize_cus()
    end)

    describe("Valid CUs", function()
      it("parses CUs", function()
        local phase = "access"
        assert.same(#edge_computing.cus[phase], 0)

        redis_smembers_resp = {"authorization"}
        redis_get_resp = phase .. "||local a = 1 \n return a"

        local resp = edge_computing.update()

        assert.same(resp, true)
        assert.same(#edge_computing.cus[phase], 1)
        local cu = edge_computing.cus[phase][1]

        assert.same(cu["id"], "authorization")
        assert.same(cu["phase"], phase)
        assert.same(type(cu["code"]), "function")
        assert.same(cu["sampling"], nil)
      end)

      it("parses CUs with sampling", function()
        local phase = "access"
        assert.same(#edge_computing.cus[phase], 0)

        redis_smembers_resp = {"authorization"}
        redis_get_resp = phase .. "||local a = 1 \n return a||85"

        local resp = edge_computing.update()

        assert.same(resp, true)
        assert.same(#edge_computing.cus[phase], 1)
        local cu = edge_computing.cus[phase][1]

        assert.same(cu["id"], "authorization")
        assert.same(cu["phase"], phase)
        assert.same(type(cu["code"]), "function")
        assert.same(cu["sampling"], "85")
      end)
    end)

    describe("Invalid CU", function()
      local unexpected_values = {
        {title="syntax error", value="access|| invalid lua code", phase="access"},
        {title="invalid phase", value="invalid_phase|| return 42", phase="access"},
        {title="invalid value", value="invalid_value", phase="access"},
        {title="empty code", value="access||", phase="access"},
        {title="empty phase", value="|| local a = 10 return a", phase="access"},
        {title="empty phase and code with separator", value="||", phase="access"},
        {title="empty phase and code", value="", phase="access"},
        {title="nil phase and code", value=nil, phase="access"},
        {title="ngx.null phase and code", value=ngx.null, phase="access"},
      }
      for _, invalid_cu in ipairs(unexpected_values) do
        it("skips " .. invalid_cu.title, function()
          redis_smembers_resp = {"authorization"}
          redis_get_resp = invalid_cu.value
          stub(edge_computing, "log")

          local resp = edge_computing.update()

          assert.same(resp, true) -- it updated but with 0 cus
          assert.same(#edge_computing.cus[invalid_cu.phase], 0)
          assert.stub(edge_computing.log).was.called(1)

          -- luacheck: ignore
          edge_computing.log:revert()
        end)
      end
    end)
  end)

  describe("#execute", function()
    before_each(function()
      -- we pressume readiness
      edge_computing.ready = true
      -- redis_client
      edge_computing.redis_client = fake_redis
      ngx_phase = "access"
    end)

    function update_cu(raw_code)
      redis_smembers_resp = {"authorization"}
      redis_get_resp = raw_code
      edge_computing.update()
    end

    it("runs code", function()
      stub(ngx, "exit")

      update_cu("access||ngx.exit(403)")
      local resp, errors = edge_computing.execute()

      assert.same(resp, true)
      assert.same(#errors, 0)
      assert.stub(ngx.exit).was.called()

      -- luacheck: ignore
      ngx.exit:revert()
    end)

    it("handles runtime error", function()
      update_cu("access||ngx.do_ia(403)")
      local resp, errors = edge_computing.execute()

      assert.same(resp, true) -- it's only false if it's not ready
      assert.same(#errors, 1)
    end)

    it("runs code accessing redis_client", function()
      stub(ngx, "say")
      stub(fake_redis, "incr")
      fake_redis.incr = function(_)
        return "1", nil
      end

      update_cu("access|| local r = edge_computing.redis_client:incr('key') \n ngx.say(r)")
      local resp, errors = edge_computing.execute()

      assert.same(resp, true)
      assert.same(#errors, 0)
      assert.stub(ngx.say).was.called_with("1")

      -- luacheck: ignore
      ngx.say:revert()
    end)

    it("runs code only for the current phase", function()
      ngx_phase = "rewrite"
      stub(ngx, "exit")

      update_cu("access||ngx.exit(403)")
      local resp, errors = edge_computing.execute()

      assert.same(resp, true)
      assert.same(#errors, 0)
      assert.stub(ngx.exit).was_not.called()

      -- luacheck: ignore
      ngx.exit:revert()
    end)

    it("does the execution based on sampling", function()
      stub(ngx, "exit")
      local builtin_rnd = math.random
      -- luacheck: ignore
      math.random = function() return 60 end

      update_cu("access||ngx.exit(403)||59") -- 59% of change
      local resp, errors = edge_computing.execute()

      assert.same(resp, true)
      assert.same(#errors, 0)
      assert.stub(ngx.exit).was.called()

      -- luacheck: ignore
      ngx.exit:revert()
      math.random = builtin_rnd
    end)

    it("skips execution based on sampling", function()
      stub(ngx, "exit")
      local builtin_rnd = math.random
      -- luacheck: ignore
      math.random = function() return 42 end

      update_cu("access||ngx.exit(403)||59") -- 3% of change
      local resp, errors = edge_computing.execute()

      assert.same(resp, true)
      assert.same(#errors, 0)
      assert.stub(ngx.exit).was_not.called()

      -- luacheck: ignore
      ngx.exit:revert()
      math.random = builtin_rnd
    end)
  end)
end)

