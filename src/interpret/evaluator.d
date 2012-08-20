module interpret.evaluator;

import std.algorithm, std.array, std.conv;
import common, parse.ast, validate.remarks, interpret.preparer, interpret.builtins;



@safe final class Evaluator : IAstVisitor!(Exp)
{
    private
    {
        IInterpreterContext context;
        PreparerForEvaluator prep;
        AstLambda currentLambda;
    }


    this (IInterpreterContext icontext)
    {
        context = icontext;
        prep = new PreparerForEvaluator(icontext);
    }


    @trusted Exp visit (AstFile file)
    {
        auto start = findDeclr(file.exps, "start");
        auto fn = cast(AstFn)start.value;
        auto s = fn ? new AstLambda(null, fn) : start.value;
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
        auto f = fna.ident.declaredBy.value.eval(this);

        auto bfn = cast(BuiltinFn)f;
        if (bfn)
        {
            Exp[] ea;
            foreach (a; fna.args)
                ea ~= a.eval(this);
            return bfn.func(context, ea);
        }

        auto fn = cast(AstFn)f;

        assert (fn, "cannot apply undefined fn");

        auto lambda = new AstLambda(currentLambda, fn);

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
            return visit(new AstLambda(currentLambda, fn));
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


    @trusted Exp visit (AstGoto gt)
    {
        if (gt.labelExpIndex == typeof(gt.labelExpIndex).max)
            context.except("goto skiped because it has no matching label");
        else
            currentLambda.currentExpIndex = gt.labelExpIndex;

        return null;
    }


    Exp visit (AstDeclr declr) { return declr.value.eval(this); }

    Exp visit (AstText text) { return text; }

    Exp visit (AstChar ch) { return ch; }

    Exp visit (AstNum num) { return num; }

    Exp visit (BuiltinFn bfn) { return bfn; }

    Exp visit (AstUnknown un) { return un; }

    Exp visit (AstStruct s) { return s; }

    Exp visit (AstLabel) { return null; }

    Exp visit (TypeAny) { return null; }

    Exp visit (TypeVoid) { return null; }

    Exp visit (TypeOr) { return null; }

    Exp visit (TypeFn) { return null; }

    Exp visit (TypeNum) { return null; }

    Exp visit (TypeText) { return null; }

    Exp visit (TypeChar) { return null; }
}