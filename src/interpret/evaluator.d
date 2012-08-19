module interpret.evaluator;

import std.algorithm, std.array, std.conv, std.string, std.file, std.utf;
import common, parse.ast, parse.parser, validate.remarks, validate.validation, interpret.preparer, interpret.builtins;



@safe final class Evaluator : AstVisitor!(Exp)
{
    private
    {
        IInterpreterContext context;
        PreparerForEvaluator prep;
        AstLambda currentLambda;
    }


    this ()
    {
        prep = new PreparerForEvaluator;
    }


    @trusted void interpret (IInterpreterContext icontext, string filePath)
    {
        immutable src = toUTF32(readText!string(filePath));
        interpret(icontext, src);
    }


    @trusted void interpret (IInterpreterContext icontext, dstring src)
    {
        auto f = (new Parser(icontext, src)).parseAll();
        auto v = new Validator(icontext);
        v.validate(f);
        interpret(icontext, f);
    }


    void interpret (IInterpreterContext icontext, AstFile file)
    {
        context = icontext;
        prep.context = context;
        visit(file);
    }


    @trusted Exp visit (AstFile file)
    {
        prep.visit(file);
        Exp s;
        auto start = findDeclr(file.exps, "start");

        if (start)
        {
            auto fn = cast(AstFn)start.value;
            s = fn ? new AstLambda(null, fn) : start.value;
        }
        else
        {
            auto fn = new AstFn(file, file);
            fn.exps = file.exps;
            s = new AstLambda(null, fn);
        }

        s.prepare(prep);
        return s.eval(this);
    }


    Exp visit (AstLambda lambda)
    {
        auto exps = lambda.fn.exps;
        lambda.currentExpIndex = 0;
        Exp e;
        while (lambda.currentExpIndex < exps.length)
        {
            currentLambda = lambda;
            e = exps[lambda.currentExpIndex].eval(this);
            ++lambda.currentExpIndex;
        }
        return e;
    }


    @trusted Exp visit (AstFnApply fna)
    {
        foreach (cfnName, cfn; customFns)
            if (cfnName == fna.ident.idents[0])
            {
                Exp[] ea;
                foreach (a; fna.args)
                    ea ~= a.eval(this);
                return cfn(context, ea);
            }

        auto fn = cast(AstFn)fna.ident.declaredBy.value.eval(this);

        assert (fn, "cannot apply undefined fn");

        auto lambda = new AstLambda(null, fn);
        lambda.parentLambda = currentLambda;

        if (fn.params)
        {
            foreach (argIx, a; fna.args)
            {
                auto d = new AstDeclr(fna, fna, fn.params[argIx].ident);
                d.value = a.eval(this);
                lambda.evaledArgs ~= d;
            }

            foreach (p; fn.params[fna.args.length .. $])
            {
                if (!p.value)
                    assert (false, "parameter has not default value so arg must be specified");

                auto d = new AstDeclr(fna, fna, p.ident);
                d.value = p.eval(this);
                lambda.evaledArgs ~= d;
            }
        }

        return visit(lambda);
    }


    Exp visit (AstIf i)
    {
        auto e = i.when.eval(this);
        if (!e)
            throw new Exception ("if test expression must not evalute to null.");

        auto when = cast(AstNum)e;
        if (!when)
            throw new Exception ("if test expression must evalute to number.");

        if (when.value == "0" && i.otherwise is null)
        {
            return null;
        }
        else
        {
            auto fn = new AstFn (i, i);
            fn.exps = when.value == "0" ? i.otherwise : i.then;
            auto l = new AstLambda(null, fn);
            l.parentLambda = currentLambda;
            return visit(l);
        }
    }


    Exp visit (AstIdent ident){

        auto d = ident.declaredBy;
        if (d.paramIndex == typeof(d.paramIndex).max)
            return d.value.eval(this);

        auto l = currentLambda;
        while (l)
        {
            if (d.parent is l.fn)
                return l.evaledArgs[d.paramIndex].value.eval(this);
            l = l.parentLambda;
        }

        assert (false, "undefined ident");
    }


    Exp visit (AstFn fn)
    {
        if (!fn.isPrepared)
            prep.visit(fn);

        return fn;
    }


    @trusted Exp visit (AstReturn ret)
    {
        auto r = ret.exp.eval(this);
        currentLambda.currentExpIndex = cast(uint)currentLambda.fn.exps.length;
        return r;
    }


    Exp visit (AstGoto gt)
    {
        currentLambda.currentExpIndex = gt.labelExpIndex;
        return null;
    }


    Exp visit (AstDeclr declr) { return declr.value.eval(this); }

    Exp visit (AstText text) { return text; }

    Exp visit (AstChar ch) { return ch; }

    Exp visit (AstNum num) { return num; }

    Exp visit (AstUnknown un) { return un; }

    Exp visit (AstStruct s) { return s; }

    Exp visit (AstLabel) { return null; }
}