module program;


import std.stdio, std.algorithm, std.string, std.array, std.conv, std.file, std.path, std.utf, std.path;
import std.file : readText, exists, isFile;
import common, settings, syntax.Formatter, validate.remarks, syntax.SyntaxValidator,
    syntax.Tokenizer, syntax.Parser, syntax.ast, interpret.Interpreter, interpret.preparer,
    validate.TypeInferer, interpret.declrfinder, interpret.builtins;


final class Program
{
    string[] filePaths;
    ValueStruct[] files;
    private dstring fileName;
    private dstring fileData;
    private ExpAssign[] starts;
    ValueStruct prog;
    bool runTests;


    this (string[] filePaths, bool runTests)
    {
        prog = new ValueStruct (null);
        this.filePaths ~= filePaths;
        //this.filePaths ~= "std.gel";
        this.runTests = runTests;
    }


    this (dstring fileName, dstring fileData)
    { 
        prog = new ValueStruct (null);
        this.fileName = fileName;
        this.fileData = fileData;
    }


    int runInConsole ()
    {
        if (runTests)
        {
            import test.tester;
            bool success = true;

            foreach (f; filePaths)
                if (f.endsWith(".txt"))
                    success = success & doTest(f);

            return 0;
        }

        auto context = new ConsoleInterpreterContext;
        context.evaluator = new Interpreter(context);
        auto res = run (context);

        if (res)
        {
            auto n = cast(ValueInt)res;
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
        {
            parseAndValidateDataAll(context);
            //findDeclarations(context, prog);
        }

        if (!prog.exps.length)
            return null;

        if (starts.length > 1)
            context.remark(textRemark("more starts functions"));

        
        //debug context.println("EVALUATE");
        //auto res = context.eval(starts[0]);

        //debug if (res) context.println("RESULT: " ~ res.str(fv));

        //return res;
        return null;
    }


    
    private void parseAndValidateDataAll (IInterpreterContext context)
    {
        if (fileData.length)
        {
            files = [prepareData(context, fileData, fileName, true)];

            if (context.hasBlocker)
            {
                context.except("context has blocker");
                return;
            }
        }
        else if (filePaths.length)
        {
            files.length = 0;
            foreach (ix, f; filePaths)
            {
                auto fileData = toUTF32(readText!string(f));
                files ~= prepareData(context, fileData, f.baseName().stripExtension().to!dstring(), ix == 0);

                if (context.hasBlocker)
                {
                    context.except("context has blocker");
                    return;
                }
            }
        }
    }


    private ValueStruct prepareData (IInterpreterContext context, dstring fileData, dstring fileName, bool isStartFile)
    {  
        debug context.println(": " ~ fileName);
        debug context.println("TOKENIZE");
        auto toks =  (new Tokenizer(fileData)).tokenize();

        debug foreach (t; toks) context.println(t.toDebugString());

        debug context.println("PARSE");
        auto par = new Parser(context, toks);
        auto astFile = par.parseAll();

        if (context.hasBlocker)
            return astFile;

        auto ttfv = new test.TokenTestFormatVisitor.TokenTestFormatVisitor;
        foreach (e; astFile.exps)
            context.println(e.str(fv) ~ "\t" ~ '"' ~ e.str(ttfv) ~ "\"\t" ~ typeid(e).name.to!dstring());

        debug context.println(astFile.str(fv));

        debug context.println("VALIDATE");
        auto val = new SyntaxValidator(context);
        val.visit(astFile);

        if (context.hasBlocker)
            return astFile;

        debug context.println("PREPARE");
        ExpAssign start;
        auto m = prepareFile(context, astFile, fileName, isStartFile, /*out*/ start, prog);
        if (start)
            starts ~= start;

        auto prep = new PreparerForEvaluator(context);
        if (isStartFile)
        {
            auto file = cast(ValueStruct)((cast(ExpAssign)m).slot).parent;
            file.prepare(prep);
        }
        else
            m.prepare(prep);

        if (context.hasBlocker)
            return astFile;

        return astFile;
    }


    private ValueStruct findDeclarations (IInterpreterContext context, ValueStruct astFile)
    {  
        debug context.println("FIND DECLARATIONS");
        initBuiltinFns();
        auto df = new DeclrFinder(context);
        df.visit(astFile);

        if (context.hasBlocker)
            return astFile;

        debug context.println("TYPE INFER");
        auto inf = new TypeInferer(context);
        inf.visit(astFile);

        debug fv.useInferredTypes = true;
        debug context.println(astFile.str(fv));

        if (context.hasBlocker)
            return astFile;

        return astFile;
    }


    static ExpAssign prepareFile (IInterpreterContext context, ValueStruct file, dstring fileName,
                           bool isFirstFile, out ExpAssign start, ValueStruct parent)
    {
        start = getStartFunction (context, file, isFirstFile);

        file.parent = parent;
        auto fna = new ExpFnApply(parent, file, null);
        auto i = new ExpIdent(parent, fileName);
        auto a = new ExpAssign(parent, i, fna);
        parent.exps ~= a;
        return a;
    }



    static private @trusted ExpAssign getStartFunction (IInterpreterContext context, ValueStruct file,
                                                 bool makeStartIfNotExists)
    {
        // todo find all starts
        auto start = findDeclr(file.exps, "start");

        if (start) 
            return start;

        if (!makeStartIfNotExists)
            return null;

        context.remark(MissingStartFunction(null));

        auto i = new ExpIdent(file, "start");
        auto a = new ExpAssign(file, i, null);
        auto fn = new ValueFn(file);
        fn.exps = file.exps;
        foreach (fne; fn.exps)
            fne.parent = fn;
        // todo set parents recursively (it is needed to set for ExpIdent, so declfinder find their delcaration  ie incNum
        // a = 1, print (a + 10)  -- second a has parent file, but should have parent fn
        a.value = fn;
        file.exps = [a];
        return a;
    }

    // todo find all starts
    static private @safe ExpAssign findDeclr (Exp[] exps, dstring name)
    {
        foreach (e; exps)
        {
            auto d = cast(ExpAssign)e;
            if (d)
            {
                auto i = cast(ExpIdent)d.slot;
                if (i && i.text == name)
                    return d;
            }
        }
        return null;
    }
}


static Program parseCmdArgs (string[] args)
{
    string[] filePaths;
    bool runTests;
    bool isError;

    foreach (a; args[1..$])
    {
        if (a.endsWith(".gel") || a.endsWith(".txt"))
        {
            immutable f = a.absolutePath().buildNormalizedPath();
            if (f.exists())
            {
                if (f.isFile())
                {
                    filePaths ~= f;
                }
                else
                {
                    isError = true;
                    cmdError ("Path \"", a, "\" not a file. It is folder or block device.",
                              " Full path is \"", f, "\".");
                }
            }
            else
            {
                isError = true;
                cmdError ("File \"", a, "\" could not be found. Full path is \"", f, "\".");
            }
        }
        else if (a == "-test")
        {
            runTests = true;
        }
        else
        {
            if (a[0] == '-' || a[0] == '/')
            {
                isError = true;
                cmdError ("Unknown command line parameter \"", a, "\".");
            }
            else
            {
                isError = true;
                cmdError ("Olny \"*.gel\" files are supported as input.",
                          " Parameters can be prefixed with \"-\", \"--\" or \"/\".");
            }
        }
    }

    if (isError)
        return null;

    return new Program(filePaths, runTests);
}


final class ConsoleInterpreterContext : IInterpreterContext
{
    private
    {
        uint remarkCounter;
        bool hasBlockerField;
        Exp[] exs;
        Interpreter evaluator;
    }


    Exp eval (Exp exp) { return exp.eval(evaluator); }

    void print (dstring str) { write (str); }

    void println () { writeln (); }

    void println (dstring str) { writeln (str); }

    dstring readln () { return std.stdio.readln().idup.to!dstring(); }

    @property bool hasBlocker () { return hasBlockerField; }

    @property Exp[] exceptions () { return exs; }


    @trusted void remark (Remark remark)
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