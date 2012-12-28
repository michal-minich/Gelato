module program;


import std.stdio, std.algorithm, std.string, std.array, std.conv, std.file, std.path, std.utf, std.path;
import std.file : readText, exists, isFile;
import common, settings, syntax.Formatter, validate.remarks, syntax.SyntaxValidator,
    syntax.Tokenizer, syntax.Parser, syntax.ast, interpret.Interpreter, interpret.preparer,
    interpret.TypeInferer, validate.UnusedNamesNotifier, interpret.NameFinder, interpret.NameAssigner, interpret.builtins, 
    interpret.ConsoleInterpreterContext;


final class Program
{
    TaskSpecs taskSpecs;
    ValueStruct prog;
    IInterpreterContext context;
    string adddFilePaths;


    this (TaskSpecs taskSpecs)
    {
        prog = new ValueStruct(null);
        prog.isModule = true;
        this.taskSpecs = taskSpecs;
        this.taskSpecs.libFolders ~= dirName(taskSpecs.startFilePath);
        adddFilePaths ~= taskSpecs.startFilePath;
    }


    int runInConsole ()
    {
        auto c = new ConsoleInterpreterContext;
        c.evaluator = new Interpreter(c);
        auto res = run(c);

        if (context.exceptions)
            return 1; // TODO some magic number here
        
        auto n = cast(ValueInt)res;
        return n ? n.value.to!int() : 0;
    }


    bool scanModules (string folder, ValueStruct parent)
    {
        if (!folder.exists())
        {
            context.remark(textRemark("lib folder does not exits"));
            return false;
        }

        bool res;

        foreach (de; folder.dirEntries(SpanMode.shallow))
        {
            if (de.isFile && de.name.endsWith(".gel"))
            {
                auto m = new ValueStruct(parent);
                m.filePath = de.name;
                auto x = de.name;
                immutable moduleName = de.name.baseName().stripExtension().to!dstring();
                addStructAsModule(m, moduleName, parent);
                res = true;
            }
            else if (de.isDir)
            {
                auto m = new ValueStruct(parent);
                immutable moduleName = de.name.baseName().stripExtension().to!dstring();
                auto a = makeModule(m, moduleName, parent);
                auto r = scanModules (de.name, m);
                if (r)
                {
                    res = true;
                    parent.exps ~= a;
                }
            }
        }

        return res;
    }


    Exp run (IInterpreterContext context)
    {
        this.context = context;

        auto fileData = taskSpecs.startFilePath
            ? toUTF32(readText!string(taskSpecs.startFilePath))
            : taskSpecs.startFileData;

        ExpAssign[] starts;

        parseAgainWithStartFn:

        auto toks = tokenize (fileData, taskSpecs.startFilePath);
        auto astFile = parse (toks);

        if (context.hasBlocker)
            return astFile;

        auto start = findName(astFile.exps, "start");

        if (!start)
        {
            fileData = "start = fn () { " ~ fileData ~ " } ";
            goto parseAgainWithStartFn;
        }

        if (start)
            starts ~= start;

        immutable moduleName = taskSpecs.startFilePath.baseName().stripExtension().to!dstring();
        auto mod = addStructAsModule(astFile, moduleName, prog);
        prepare(mod);

        if (context.hasBlocker)
            return null;

        foreach (lf; taskSpecs.libFolders)
            scanModules(lf, prog);

        initBuiltinFns();

        findDeclarations();
        
        if (context.hasBlocker)
            return null;

        typeInfer();

        notifyUnusedNames();

        if (context.hasBlocker)
            return astFile;

        if (starts.length > 1)
        {
            context.remark(textRemark("more starts functions"));
            return null;
        }

        return eval (starts[0]);
    }


    ValueStruct loadFile (string filePath)
    {
        if (adddFilePaths.canFind(filePath))
            return null;

        auto fileData = toUTF32(readText!string(filePath));

        auto moduleName = filePath.baseName().stripExtension().to!dstring();

        auto toks = tokenize (fileData, filePath);
        auto astFile = parse (toks);

        if (context.hasBlocker)
            return null;

        prepare(astFile);

        adddFilePaths ~= filePath;

        return astFile;
        // TODO how to handle stop on blocker in declrfinder 
        //if (context.hasBlocker)
        ///    return;
    }


    private:


    Token[] tokenize (dstring fileData, string fileName)
    {
        debug context.println("TOKENIZE " ~  fileName.to!dstring());
        auto toks = (new Tokenizer(fileData)).tokenize();
        //debug foreach (t; toks) context.println(t.toDebugString());
        return toks;
    }
    

    ValueStruct parse (Token[] toks)
    {
        debug context.println("PARSE");
        auto par = new Parser(context, toks);
        return par.parseAll();
    }


    void validateSyntax (ValueStruct astFile)
    {
        debug context.println("VALIDATE SYNTAX");
        auto val = new SyntaxValidator(context);
        val.visit(astFile);
    }


    void prepare (Exp e)
    {
        debug context.println("PREPARE");
        auto prep = new PreparerForEvaluator(context);
        e.accept(prep);
    }


    static ExpAssign addStructAsModule (ValueStruct astFile, dstring moduleName, ValueStruct parent)
    {
        auto a = makeModule(astFile, moduleName, parent);
        parent.exps ~= a;
        return a;
    }


    static ExpAssign makeModule (ValueStruct astFile, dstring moduleName, ValueStruct parent)
    {
        astFile.parent = parent;
        astFile.isModule = true;
        auto fna = new ExpFnApply(parent, astFile, null);
        auto i = new ExpIdent(parent, moduleName);
        auto a = new ExpAssign(parent, i, fna);
        i.declaredBy = a;
        return a;
    }


    void findDeclarations ()
    {
        debug context.println("FIND NAMES");
        auto nf = new NameFinder(context);
        nf.visit(prog);

        debug context.println("ASSIGN NAMES");
        auto na = new NameAssigner(context);
        na.visit(prog);
    }


    void typeInfer ()
    {
        debug context.println("TYPE INFER");
        auto inf = new TypeInferer(this, context);
        inf.visit(prog);
        debug fv.useInferredTypes = true;
        debug context.println(prog.str(fv));
    }


    void notifyUnusedNames ()
    {
        debug context.println("UNUSED NAMES");
        auto unn = new UnusedNamesNotifier(context);
        unn.visit(prog);
    }


    Exp eval (ExpAssign start)
    {
        debug context.println("EVALUATE");

        auto fn = cast(ValueFn)start.value;
        Exp start2;
        if (fn)
        {
            auto i = new ExpIdent(fn.parent, "start");
            i.declaredBy = start;
            start2 = new ExpFnApply(fn.parent, i, null);
        }
        else
        {
            start2 = start.value;
        }

        auto res = context.eval(start2);

        debug if (res) context.println("RESULT: " ~ res.str(fv));

        return res;
    }


    // todo find all starts deeply
    static @safe ExpAssign findName (Exp[] exps, dstring name)
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


struct TaskSpecs
{
    TaskAction action;
    string startFilePath;
    dstring startFileData;
    string[] libFolders;
}



enum TaskAction { none, tokenize, parse, validateSyntax, typeInfer, run, test }


static TaskSpecs parseCmdArgs (string[] args)
{
    string[] filePaths;
    bool isError;

    if (args.length == 1)
    {
        cmdPrint ("todo display help here");
        return TaskSpecs();
    }

    foreach (a; args[1..$])
    {
        if (a.endsWith(".gel") || a.endsWith(".geltest"))
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
                    cmdPrint ("Path \"", a, "\" not a file. It is folder or block device.",
                              " Full path is \"", f, "\".");
                }
            }
            else
            {
                isError = true;
                cmdPrint ("File \"", a, "\" could not be found. Full path is \"", f, "\".");
            }
        }
        else
        {
            if (a[0] == '-' || a[0] == '/')
            {
                isError = true;
                cmdPrint ("Unknown command line parameter \"", a, "\".");
            }
            else
            {
                isError = true;
                cmdPrint ("Only \"*.gel\" files are supported as input.",
                          " Parameters can be prefixed with \"-\", \"--\" or \"/\".");
            }
        }
    }

    if (!filePaths)
    {
        isError = true;
        cmdPrint("No files specified");
    }
    else if (filePaths.length > 1)
    {
        isError = true;
        cmdPrint("Only one file needs to be provided (the one with start function). ",
                 "All others are taken automatically if needed.");
    }

    if (isError)
        return TaskSpecs();

    return TaskSpecs(TaskAction.run, filePaths[0]);
}
