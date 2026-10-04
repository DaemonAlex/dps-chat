local C = Logic.cleanText
-- text cleaning
check('plain text kept', C('waves at you') == 'waves at you')
check('GTA colour codes removed', C('~r~red ~h~bold~s~ text') == 'red bold text')
check('stray tilde removed', C('a ~ b') == 'a b')
check('newline becomes space', C('one\ntwo') == 'one two')
check('tabs and runs of spaces squashed', C('  a \t\t b  ') == 'a b')
check('angle brackets removed', C('<img src=x>hi') == 'img src=xhi')
check('empty gives nil', C('') == nil)
check('only codes gives nil', C('~r~~b~') == nil)
check('non-string gives nil', C(42) == nil and C(nil) == nil)
check('capped at 120', #C(string.rep('a', 500)) == 120)
check('custom cap', C('abcdef', 3) == 'abc')
local cut = C(string.rep('é', 100))   -- 200 bytes
check('never cuts a character in half', cut ~= nil and utf8.len(cut) ~= nil and #cut <= 120)
-- rate gate
local g = {}
check('first call allowed', Logic.rateOk(g, 'k', 1000, 3000))
check('second call too soon', not Logic.rateOk(g, 'k', 2000, 3000))
check('allowed after the gap', Logic.rateOk(g, 'k', 4000, 3000))
check('other key not blocked', Logic.rateOk(g, 'other', 4001, 3000))
-- repeats
local r = {}
check('first line not a repeat', not Logic.isRepeat(r, 1, 'hi', 0))
check('same line soon is a repeat', Logic.isRepeat(r, 1, 'hi', 5000))
check('other line not a repeat', not Logic.isRepeat(r, 1, 'bye', 5000))
check('same line later is fine', not Logic.isRepeat(r, 1, 'bye', 20000))
-- box spot
local V = Logic.validPos
check('good spot kept', V({ x = 10, y = 90 }).x == 10)
check('numbers as text accepted', V({ x = '12.5', y = '3' }).x == 12.5)
check('rounded to 2 places', V({ x = 1.23456, y = 0 }).x == 1.23)
check('off screen refused', V({ x = -1, y = 5 }) == nil and V({ x = 5, y = 101 }) == nil)
check('missing value refused', V({ x = 5 }) == nil)
check('not a table refused', V('x') == nil and V(nil) == nil)
check('NaN refused', V({ x = 0/0, y = 1 }) == nil)
-- command names
check('normal command listed', Logic.listable('film'))
check('key-mapping halves hidden', not Logic.listable('+dpschat') and not Logic.listable('-dpschat'))
check('internal hidden', not Logic.listable('_debug'))
check('junk hidden', not Logic.listable(nil) and not Logic.listable('') and not Logic.listable(string.rep('a', 65)))
