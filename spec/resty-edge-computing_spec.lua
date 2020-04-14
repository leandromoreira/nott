package.path = package.path .. ";spec/?.lua"

local edge_computing = require "resty-edge-computing"

describe("Resty Edge Computing", function()
  it("returns the list", function()
    local resp, err = edge_computing.list()

    assert.is_nil(err)
    assert.same({}, resp)
  end)
end)
