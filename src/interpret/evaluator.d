module interpret.evaluator;

import std.algorithm, std.array, std.conv;
import common, parse.ast, validate.remarks, interpret.preparer, interpret.builtins, 
    interpret.declrfinder;



@safe final class Evaluator : IAstVisitor!(Exp)
{
    private
    {
        IInterpreterContext context;
        PreparerForEvaluator prep;
        RtExpScope currentScope;
    }


    this (IInterpreterContext icontext)
    {
        context = icontext;
        prep = new PreparerForEvaluator(icontext);
    }


    @trusted Exp eval (ExpAssign start)
    {
        auto fn = cast(ValueFn)start.value;
        auto s = fn ? new RtExpLambda(null, null, fn) : start.value;
        return s.eval(this);
    }


    Exp visit (RtExpLambda lambda)
    {
        auto exps = lambda.fn.exps;
        lambda.currentExpIndex = 0;
        Exp lastExp;
        Exp e;
        while (lambda.currentExpIndex < exps.length)
        {
            currentScope = lambda;
            lastExp = exps[lambda.currentExpIndex];
            e = lastExp.eval(this);
            ++lambda.currentExpIndex;
        }

        return exps.length == 1 || cast(StmReturn)lastExp ? e : null;
    }


    @trusted Exp visit (ExpFnApply fna)
    {
        auto exp = fna.applicable.eval(this);
        auto f = cast(ValueFn)exp;

        if (!f)
        {
            auto bfn = cast(ValueBuiltinFn)exp;
            if (bfn)
            {
                Exp[] ea;
                foreach (a; fna.args)
                    ea ~= a.eval(this);
                
                try
                {
                    return bfn.func(context, ea);
                }
                catch (Exception ex)
                {
                    // TODO handle properly
                    return ValueUnknown.single;
                }
            }

            auto s = cast(ValueStruct)exp;
            if (s)
            {
                auto assigments = cast(ExpAssign[])s.exps; // sure cast
                auto sc = new RtExpScope(currentScope.parent, currentScope, assigments);

                foreach (a; assigments)
                    sc.values ~= a.value.eval(this);

                return sc;
            }

            assert (false, "only fn, built in fn or struct can be applied (" 
                    ~ exp.str(fv).toString() ~ ", " ~ typeid(exp).name ~ ")");
        }

        auto fn = cast(ValueFn)f;

        assert (fn, "cannot apply undefined fn");

        auto lambda = new RtExpLambda(currentScope.parent, currentScope, fn);

        if (fn.params)
        {
            foreach (a; fna.args)
                lambda.values ~= a.eval(this);

            foreach (p; fn.params[fna.args.length .. $])
            {
                assert (p.value, "parameter has not default value so argument must be specified");
                lambda.values ~= p.eval(this);
            }
        }

        return visit(lambda);
    }


    Exp visit (ExpIf i)
    {
        auto e = i.when.eval(this);
        if (!e)
            throw new Exception ("if test expression must not evaluate to null.");

        auto when = cast(ValueNum)e;
        if (!when)
            throw new Exception ("if test expression must evaluate to number.");

        if (!when.value && !i.otherwise)
        {
            return null;
        }
        else
        {
            auto fn = new ValueFn (currentScope.parent);
            fn.exps = when.value ? i.then : i.otherwise;
            return visit(new RtExpLambda(currentScope.parent, currentScope, fn));
        }
    }


    Exp visit (ExpIdent ident)
    {
        auto d = ident.declaredBy;
        if (d.paramIndex == typeof(d.paramIndex).max)
            return d.value.eval(this);

        auto s = currentScope;
        while (s)
        {
            auto l = cast(RtExpLambda)s;
            if (l && d.parent is l.fn)
                return s.values[d.paramIndex];
            s = s.parentScope;
        }

        assert (false);
    }


    Exp visit (ValueFn fn)
    {
        if (!fn.isPrepared)
            prep.visit(fn);

        return fn;
    }


    @trusted Exp visit (ExpDot dot)
    {
        auto record = dot.record.eval(this);

        auto st = cast(ValueStruct)record;

        assert (!st, "struct must be constructed before accessing member (" 
                ~ dot.member.toString() ~ ")");

        auto sc = cast(RtExpScope)record;

        assert (sc, "only struct can have members (" ~ dot.member.toString() ~ ")");
        
        foreach (ix, d; sc.assigments)
            if ((cast(ExpIdent)d.slot).text == dot.member)
                return sc.values[ix].eval(this);

        assert (false, "struct has no member " ~ dot.member.to!string());
    }


    @trusted Exp visit (StmReturn ret)
    {
        auto r = ret.exp.eval(this);
        auto currentLambda = cast(RtExpLambda)currentScope;
        currentLambda.currentExpIndex = cast(uint)currentLambda.fn.exps.length;
        return r;
    }


    @trusted Exp visit (StmGoto gt)
    {
        if (gt.labelExpIndex == typeof(gt.labelExpIndex).max)
            context.except("goto skipped because it has no matching label");
        else
        {
            auto currentLambda = cast(RtExpLambda)currentScope;
            currentLambda.currentExpIndex = gt.labelExpIndex;
        }

        return null;
    }

    Exp visit (ExpAssign a)
    { 
        if (a.value)
        {
            auto v = a.value.eval(this);
            auto s = a.slot;//.eval(this);
            auto i = cast(ExpIdent)s;
            if (i)
                i.declaredBy.value = v;
            else
                assert(false, "value is not assignable");
            return v;
        }

        return null;
    }

    Exp visit (RtExpScope sc) { return sc; }

    Exp visit (ValueText text) { return text; }

    Exp visit (ValueChar ch) { return ch; }

    Exp visit (ValueNum num) { return num; }

    Exp visit (ValueBuiltinFn bfn) { return bfn; }

    Exp visit (ValueUnknown un) { return un; }

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

    Exp visit (TypeStruct) { return null; }

    // BUG: todo should return value of most recent expression (or not be evaluated - removed in preparer)
    Exp visit (WhiteSpace ws) { return null; }
}