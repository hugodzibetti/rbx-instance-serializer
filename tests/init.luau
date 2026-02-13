local frktest = require("@packages/frktest")

require("@self/Serialization.spec")()

local console_reporter = frktest._reporters.lune_console_reporter
console_reporter.init()

frktest.run()