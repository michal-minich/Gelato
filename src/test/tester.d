module test.tester;


import std.stdio, std.range, std.range, std.algorithm, std.conv, std.string, std.utf, std.path;
import std.file : exists, isFile;

import common, settings, syntax.Formatter, syntax.ast, syntax.Parser, syntax.Tokenizer, validate.remarks,
       syntax.SyntaxValidator, interpret.preparer, interpret.Interpreter, program;
import test.TestFormatVisitor, test.TestInterpreterContext, test.TokenTestFormatVisitor;


bool doTest (string filePath)
{
    auto testsExecuted = 0;
    auto testsFailed = 0;
    auto testsCrashed = 0;
    auto testsSkipped = 0;

    dstring testPrefix = "";

    auto tfv = new TestFormatVisitor;
    auto ttfv = new TokenTestFormatVisitor;

    foreach (ln; File(filePath).byLine())
    {
        auto line = ln.chomp().to!dstring();
        if (line.length > 0 && line[0] == '@')
        {
            testPrefix = line[2 .. $ - 2].to!dstring();
            continue;
        }

        if (line.startsWith("--"))
        {
            ++testsSkipped;
            continue;
        }

        auto tabIx = line.countUntil('\t');

        if (tabIx == -1)
        {
            testPrefix = "";
            continue;
        }

        ++testsExecuted;

        auto expectedStr = line[1 .. tabIx - 1];
        auto expected = expectedStr.replace("\\n", "\n").replace("\\r", "\r").replace("\\t", "\t");
        auto codeStartIx = tabIx + line[tabIx .. $].countUntil('"') + 1;
        auto codeStart = line[codeStartIx .. $];
        auto codeEndIx = line.length - line.retro().countUntil('"') - 1;
        auto code = line[codeStartIx .. codeEndIx];
        auto tokTestStartIx = line[codeEndIx .. $].countUntil('|');
        dstring tokensExpected;
        if (tokTestStartIx != -1)
        {
            auto l = line[codeEndIx + tokTestStartIx .. $];
            tokensExpected ='|' ~ code.idup ~ l;
        }
        auto thisFailed = false;
        auto context = new TestInterpreterContext;
        context.evaluator = new Interpreter(context);
        auto fullCode = testPrefix ~ code;
        auto tokenFailed = false;
        dstring tokensParsed;

        try
        {
            auto p = new Program(TaskSpecs(TaskAction.run, null, fullCode));
            auto res = p.run(context);

            if (context.hasBlocker)
            {
                ++testsFailed;
                errPrint(fullCode, context);
                continue;
            }

            if (res is null && expected == "\\0")
                continue;

            auto tt = p.prog.exps[0].tokensText;

            auto resStr = res.str(tfv);

            auto evalFailed = resStr != expected;

            if (tokensExpected != tokensParsed || tokenFailed || evalFailed || context.remarks || context.exceptions)
            {
                if (tokensExpected.length)
                    tokensParsed = '|' ~ p.prog.exps[0].str(ttfv) ~ '|';
                else
                {
                    tokensExpected = '|' ~ fullCode ~ '|';
                    tokensParsed ='|' ~ (cast(ExpAssign)p.prog.exps[0]).value.tokensText ~ '|';
                }

                ++testsFailed;
                errPrint(fullCode, context, expectedStr, resStr, tokensExpected, tokensParsed);
                continue;
            }
        }
        catch (Throwable t)
        {
            ++testsCrashed;
            thisFailed = true;
            writeln("Code:      ", fullCode);
            writeln("Expected:  ", "\"" ~ expected ~ "\"");
            writeln("Exception:  " ~ typeid(t).name ~ " - ", t.msg);
            writeln("-------------------------------------------------------------------------------");
        }
    }

    if (testsFailed == 0 && testsCrashed == 0)
        write("ALL OK, ");

    write(testsExecuted, " tests executed");

    if (testsFailed != 0)
        write(", ", testsFailed, " failed");

    if (testsCrashed != 0)
        write(", ", testsCrashed, " crashed");

    if (testsSkipped != 0)
        write(", ", testsSkipped, " skipped");

    writeln();

    return testsFailed == 0 && testsCrashed == 0;
}


void errPrint (dstring code, TestInterpreterContext context)
{
    errPrint (code, context, null, null, null, null);
}


void errPrint (dstring code, TestInterpreterContext context, 
               dstring expected, dstring resStr, 
               dstring tokensExpected, dstring tokensParsed)
{
    writeln("Code:     ", code);

    if (expected !is null && resStr !is null)
    {
        writeln("Expected: ", "\"" ~ expected ~ "\"");
        writeln("Result:   ", "\"" ~ resStr ~ "\"");
    }

    if (tokensExpected != tokensParsed)
    {
        writeln("Expected Tokens: ", tokensExpected);
        writeln("Result Tokens:   ", tokensParsed);
    }

    foreach (r; context.remarks)
        writeln("Remark:   ", r.severity, " - ", r.text);

    foreach (ex; context.exceptions)
        writeln("App Exception: ", ex);

    writeln("-------------------------------------------------------------------------------");
}
