module interpret.evaluator;

import std.algorithm, std.array, std.conv;
import common, parse.ast, validate.remarks, interpret.preparer, interpret.builtins;



@safe final class Evaluator : IAstVisitor!(Exp)
{
    private
    {
        IInterpreterContext context;
        PreparerForEvaluator prep;
        ExpLambda currentLambda;
    }


    this (IInterpreterContext icontext)
    {
        context = icontext;
        prep = new PreparerForEvaluator(icontext);
    }


    @trusted Exp visit (ValueFile file)
    {
        auto start = findDeclr(file.exps, "start");
        auto fn = cast(ValueFn)start.value;
        auto s = fn ? new ExpLambda(null, fn) : start.value;
        return s.eval(this);
    }


    Exp visit (ExpLambda lambda)
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


    @trusted Exp visit (ExpFnApply fna)
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

        auto fn = cast(ValueFn)f;

        assert (fn, "cannot apply undefined fn");

        auto lambda = new ExpLambda(currentLambda, fn);

        if (fn.params)
        {
            foreach (argIx, a; fna.args)
            {
                auto d = new StmDeclr(fna, fn.params[argIx].ident);
                d.value = a.eval(this);
                lambda.evaledArgs ~= d;
            }

            foreach (p; fn.params[fna.args.length .. $])
            {
                if (!p.value)
                    assert (false, "parameter has not default value so arg must be specified");

                auto d = new StmDeclr(fna, p.ident);
                d.value = p.eval(this);
                lambda.evaledArgs ~= d;
            }
        }

        return visit(lambda);
    }


    Exp visit (ExpIf i)
    {
        auto e = i.when.eval(this);
        if (!e)
            throw new Exception ("if test expression must not evalute to null.");

        auto when = cast(ValueNum)e;
        if (!when)
            throw new Exception ("if test expression must evalute to number.");

        if (!when.value && !i.otherwise)
        {
            return null;
        }
        else
        {
            auto fn = new ValueFn (i);
            fn.exps = when.value ? i.then : i.otherwise;
            return visit(new ExpLambda(currentLambda, fn));
        }
    }


    Exp visit (ExpIdent ident){

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


    Exp visit (ValueFn fn)
    {
        if (!fn.isPrepared)
            prep.visit(fn);

        return fn;
    }


    @trusted Exp visit (StmReturn ret)
    {
        auto r = ret.exp.eval(this);
        currentLambda.currentExpIndex = cast(uint)currentLambda.fn.exps.length;
        return r;
    }


    @trusted Exp visit (StmGoto gt)
    {
        if (gt.labelExpIndex == typeof(gt.labelExpIndex).max)
            context.except("goto skiped because it has no matching label");
        else
            currentLambda.currentExpIndex = gt.labelExpIndex;

        return null;
    }


    Exp visit (StmDeclr d) { return d.value ? d.value.eval(this) : null; }

    Exp visit (ValueText text) { return text; }

    Exp visit (ValueChar ch) { return ch; }

    Exp visit (ValueNum num) { return num; }

    Exp visit (BuiltinFn bfn) { return bfn; }

    Exp visit (AstUnknown un) { return un; }

    Exp visit (ValueStruct s) { return s; }

    Exp visit (StmLabel) { return null; }

    Exp visit (TypeType) { return null; }

    Exp visit (TypeAny) { return null; }

    Exp visit (TypeVoid) { return null; }

    Exp visit (TypeOr) { return null; }

    Exp visit (TypeFn) { return null; }

    Exp visit (TypeNum) { return null; }

    Exp visit (TypeText) { return null; }

    Exp visit (TypeChar) { return null; }
}