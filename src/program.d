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
    private dstring fileName;
    private dstring fileData;
    private ExpAssign[] starts;
    ValueStruct prog;


    this (string[] filePaths)
    {
        prog = new ValueStruct (null);
        this.filePaths ~= filePaths;
        this.filePaths ~= "std.gel";
    }


    this (dstring fileName, dstring fileData)
    { 
        prog = new ValueStruct (null);
        this.fileName = fileName;
        this.fileData = fileData;
    }


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

        if (!prog.exps.length)
            return null;

        if (starts.length > 1)
            context.remark(textRemark("more starts functions"));

        debug context.println("EVALUATE");
        auto ev = new Evaluator(context);
        auto res = ev.eval(starts[0]);

        debug if (res) context.println("RESULT: " ~ res.str(fv));

        return res;
    }

    
    private void prepareFiles (IInterpreterContext context)
    {
        if (fileData.length)
        {
            files.length = 0;
            auto m = prepareData(context, fileData, fileName, true);

            if (context.hasBlocker)
            {
                context.except("context has blocker");
                return;
            }

             prog.exps ~= cast(ExpAssign)m;
        }
        else if (filePaths.length)
        {
            foreach (ix, f; filePaths)
            {
                auto fileData = toUTF32(readText!string(f));
                auto m = prepareData(context, fileData, f.baseName().stripExtension().to!dstring(), ix == 0);

                if (context.hasBlocker)
                {
                    context.except("context has blocker");
                    return;
                }

                prog.exps ~= cast(ExpAssign)m;
            }
        }
    }



    private Exp prepareData (IInterpreterContext context, dstring fileData, dstring fileName,
                             bool isStartFile)
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
        ExpAssign start;
        auto m = prep.prepareFile(context, astFile, fileName, isStartFile, /*out*/ start, prog);
        if (start)
            starts ~= start;

        if (context.hasBlocker)
            return m;
        
        /*
        debug context.println("TYPE INFER");
        auto inf = new TypeInferer(context);
        inf.visit(astFile);

        if (context.hasBlocker)
            return astFile;
        */

        return m;
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