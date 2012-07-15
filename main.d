module main;

import std.stdio, std.array, std.algorithm, std.conv, std.utf, std.file, std.path;
import common, tokenizer/* ,ast, interpreter*/;


int main (string[] args)
{
    auto task = InterpretTask.parse(args);

    process (task);

    return 0;
}


void process (InterpretTask task)
{
    foreach (f; task.files)
    {
        auto src = toUTF32(readText!string(f));
        auto tzr = new Tokenizer;
        auto toks = tzr.tokenize(src);

        foreach (t; toks)
            writeln(t.toDebugString());
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
                auto f = a.absolutePath();
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
