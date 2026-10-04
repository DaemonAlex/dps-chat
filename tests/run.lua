-- lua5.4 tests/run.lua  (from the resource folder). Exits non-zero on any failure.
package.path = './?.lua;' .. package.path
dofile('tests/stubs.lua')
dofile('shared/logic.lua')
local pass, fail = 0, 0
function check(name, cond)
    if cond then pass = pass + 1 else fail = fail + 1; print('FAIL ' .. name) end
end
for _, f in ipairs({ 'tests/test_logic.lua' }) do dofile(f) end
print(('%d checks, %s'):format(pass + fail, fail == 0 and 'ALL PASS' or (fail .. ' FAILED')))
os.exit(fail == 0 and 0 or 1)
