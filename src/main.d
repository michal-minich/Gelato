module main;


import std.stdio, std.array, std.algorithm, std.conv, std.utf, std.file, std.path;
import common, settings, formatter, parse.tokenizer, parse.parser, parse.ast, 
    interpret.interpreter, interpret.evaluator;


int main (string[] args)
{
    fv = new FormatVisitor;
    sett = Settings.beforeLoad;
    sett = Settings.load (
        new LoadSettingsInterpreterContext(new ConsoleInterpreterContext),
        dirName(buildNormalizedPath(args[0])));

    auto task = InterpretTask.parse(args);

    process (task);

    return 0;
}


void process (InterpretTask task)
{
    foreach (f; task.files)
    {
        immutable src = toUTF32(readText!string(f));

        auto toks = new Tokenizer (src);
        //foreach (t; toks)
        //    writeln(t.toDebugString());

        auto ast = new Parser(sett.icontext, src);
        auto astFile = ast.parseAll();
        /*foreach (e; f.exps)
        {
            writeln(e.str(fv));

            foreach (t; e.tokens)
                writeln(t);
        }*/

        //auto i = new Interpreter;
       //auto env = i.interpret (sett.icontext, f);

        //auto p = new PreparerForEvaluator;
        //astFile.prepare(p);

        auto ev = new Evaluator;
        ev.interpret (sett.icontext, astFile);

       // writeln(astFile.str(fv));
    }
}


struct InterpretTask
{
    string[] files;

    static InterpretTask parse (string[] args)
    {
        InterpretTask task;

        foreach (a; args[1..$])
        {
            if (a.endsWith(".gel"))
            {
                immutable f = a.buildNormalizedPath();
                if (f.exists())
                {
                    if (f.isFile())
                    {
                        task.files ~= f;
                    }
                    else
                    {
                        cmdError ("Path \"", a, "\" not a file. It is folder or block device.",
                                  " Full path is \"", f, "\".");
                    }
                }
                else
                {
                    cmdError ("File \"", a, "\" could not be found. Full path is \"", f, "\".");
                }
            }
            else
            {
                if (a[0] == '-' || a[0] == '/')
                {
                    cmdError ("Unknown command line parameter \"", a, "\".");
                }
                else
                {
                    cmdError ("Olny \"*.gel\" files are supported as input.",
                              " Parameters can be prefixed with \"-\", \"--\" or \"/\".");
                }
            }
        }

        return task;
    }
}


void cmdError (string[] text ...)
{
    foreach (t; text)
        write (t);

    writeln();
}