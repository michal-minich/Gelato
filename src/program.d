module program;


import std.stdio, std.algorithm, std.string, std.array, std.conv, std.file, std.path, std.utf, std.path;
import std.file : readText, exists, isFile;
import common, settings, formatter, validate.remarks, validate.validation,
    parse.tokenizer, parse.parser, parse.ast, interpret.evaluator, interpret.preparer,
    validate.inferer, interpret.declrfinder;


final class Program
{
    string[] filePaths;
    ValueStruct[] files;
    private dstring fileData;
    private ExpAssign start;


    this (string[] filePaths) { this.filePaths = filePaths; }

    this (dstring fileData) { this.fileData = fileData; }


    int runInConsole ()
    {
        auto context = new ConsoleInterpreterContext;
        auto res = run (context);

        if (res)
        {
            auto n = cast(ValueNum)res;
            return n ? n.value.to!int() : 0;
        }
        else
        {
            return context.exceptions.length != 0;
        }
    }


    Exp run (IInterpreterContext context)
    {
        if (!files.length)
            prepareFiles(context);

        if (!files.length)
            return null;

        debug context.println("EVALUATE");
        auto ev = new Evaluator(context);
        auto res = ev.eval(files[0]);

        debug if (res) context.println("RESULT: " ~ res.str(fv));

        return res;
    }


    private void prepareFiles (IInterpreterContext context)
    {
        if (fileData.length)
        {
            files.length = 0;
            files ~= prepareData(context, fileData, true);

            start = getStartFunction(context);

            if (context.hasBlocker)
            {
                context.except("context has blocker");
                return;
            }
        }
        else if (filePaths.length)
        {
            foreach (ix, f; filePaths)
            {
                auto fileData = toUTF32(readText!string(f));
                files ~= prepareData(context, fileData, ix == 0);

                if (ix == 0)
                    start = getStartFunction(context);

                if (context.hasBlocker)
                {
                    context.except("context has blocker");
                    return;
                }
            }
        }
    }


    private @trusted ExpAssign getStartFunction (IInterpreterContext context)
    {
        foreach (f; files)
        {
            auto start = findDeclr(f.exps, "start");
            if (start) 
                return start;
        }

        auto f = files[0];
        context.remark(MissingStartFunction(null));
        auto i = new ExpIdent(f, "start");
        auto a = new ExpAssign(f, i);
        auto fn = new ValueFn(f);
        fn.exps = f.exps;
        a.value = fn;
        f.exps = [a];
        return a;
    }


    private ValueStruct prepareData (IInterpreterContext context, dstring fileData, bool isStartFile)
    {  
        debug context.println("TOKENIZE");
        auto toks =  (new Tokenizer(fileData)).array();

        debug context.println("PARSE");
        auto par = new Parser(context, toks);
        auto astFile = par.parseAll();

        if (context.hasBlocker)
            return astFile;

        debug context.println("VALIDATE");
        auto val = new Validator(context);
        val.visit(astFile);

        if (context.hasBlocker)
            return astFile;

        debug context.println("PREPARE");
        auto prep = new PreparerForEvaluator(context);
        prep.prepareFile(astFile, isStartFile); 

        if (context.hasBlocker)
            return astFile;
        
        /*
        debug context.println("TYPE INFER");
        auto inf = new TypeInferer(context);
        inf.visit(astFile);

        if (context.hasBlocker)
            return astFile;
        */

        return astFile;
    }
}


static Program parseCmdArgs (string[] args)
{
    string[] filePaths;

    foreach (a; args[1..$])
    {
        if (a.endsWith(".gel"))
        {
            immutable f = a.buildNormalizedPath();
            if (f.exists())
            {
                if (f.isFile())
                {
                    filePaths ~= f;
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

    return new Program(filePaths);
}


final class ConsoleInterpreterContext : IInterpreterContext
{
    private
    {
        uint remarkCounter;
        bool hasBlockerField;
        Exp[] exs;
    }


    void print (dstring str) { write (str); }

    void println () { writeln (); }

    void println (dstring str) { writeln (str); }

    dstring readln () { return std.stdio.readln().idup.to!dstring(); }

    @property bool hasBlocker () { return hasBlockerField; }

    @property Exp[] exceptions () { return exs; }


    void remark (Remark remark)
    {
        auto svr = remark.severity;

        if (svr == RemarkSeverity.blocker)
            hasBlockerField = true;

        std.stdio.write (++remarkCounter, "\t", svr, "\t", remark.text);

        if (remark.subject)
            std.stdio.write ("\t", remark.subject.tokensText);

        writeln();
    }

    nothrow void except (dstring ex)
    {
        try
        {
            exs ~= new ValueText(null, ex);
            return writeln("exception\t", ex);
        }
        catch (Exception ex)
        {
            assert (false, ex.msg);
        }
    }
}