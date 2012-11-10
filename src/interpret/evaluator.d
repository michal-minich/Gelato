module interpret.evaluator;

import std.algorithm, std.array, std.conv;
import common, ast, validate.remarks, interpret.preparer, interpret.builtins, 
    interpret.declrfinder;



@safe final class Evaluator : IAstVisitor!(Exp)
{
    private
    {
        IInterpreterContext context;
        PreparerForEvaluator prep;
        Closure currentClosure;
    }


    this (IInterpreterContext icontext)
    {
        context = icontext;
        prep = new PreparerForEvaluator(icontext);
    }


    @trusted Exp eval (ExpAssign start)
    {
        auto fn = cast(ValueFn)start.value;
        auto s = fn ? new RtExpLambda(fn, null) : start.value;
        return s.eval(this);
    }


    Exp visit (RtExpLambda lambda)
    {
        auto exps = lambda.parent.exps;
        lambda.currentExpIndex = 0;
        Exp lastExp;
        Exp e;
        while (lambda.currentExpIndex < exps.length)
        {
            currentClosure = lambda;
            lastExp = exps[lambda.currentExpIndex];
            e = lastExp.eval(this);
            ++lambda.currentExpIndex;
        }

        return exps.length == 1 || cast(StmReturn)lastExp ? e : null;
    }


    @trusted Exp visit (ExpFnApply fna)
    {
        auto exp = fna.applicable.eval(this);
        auto fn = cast(ValueFn)exp;

        if (!fn)
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
                auto declarations = cast(ExpAssign[])s.exps; // sure cast
                auto sc = new Closure(currentClosure.parent, currentClosure, declarations);

                foreach (a; declarations)
                    sc.values ~= a.value.eval(this);

                return sc;
            }

            assert (false, "only fn, built in fn or struct can be applied (" 
                    ~ exp.str(fv).toString() ~ ", " ~ typeid(exp).name ~ ")");
        }

        assert (fn, "cannot apply undefined fn");

        auto lambda = new RtExpLambda(fn, currentClosure);

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
            auto fn = new ValueFn (currentClosure.parent);
            fn.exps = when.value ? i.then : i.otherwise;
            return visit(new RtExpLambda(fn, currentClosure));
        }
    }


    Exp visit (ExpIdent ident)
    {
        auto d = ident.declaredBy;
        if (d.paramIndex == typeof(d.paramIndex).max)
            return d.value.eval(this);

        auto c = currentClosure;
        do
        {
            if (d.parent is c.parent)
                return c.values[d.paramIndex];
            c = c.closure;
        } while (c);

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

        auto sc = cast(Closure)record;

        assert (sc, "only struct can have members (" ~ dot.member.toString() ~ ")");
        
        foreach (ix, d; sc.declarations)
            if ((cast(ExpIdent)d.slot).text == dot.member)
                return sc.values[ix].eval(this);

        assert (false, "struct has no member " ~ dot.member.to!string());
    }


    @trusted Exp visit (StmReturn ret)
    {
        auto r = ret.exp.eval(this);
        auto currentLambda = cast(RtExpLambda)currentClosure;
        currentLambda.currentExpIndex = cast(uint)currentClosure.parent.exps.length;
        return r;
    }


    @trusted Exp visit (StmGoto gt)
    {
        if (gt.labelExpIndex == typeof(gt.labelExpIndex).max)
            context.except("goto skipped because it has no matching label");
        else
        {
            auto currentLambda = cast(RtExpLambda)currentClosure;
            currentLambda.currentExpIndex = gt.labelExpIndex;
        }

        return null;
    }

    Exp visit (ExpAssign a)
    { 
        auto v = a.expValue.eval(this);
        auto s = a.slot;//.eval(this);
        auto i = cast(ExpIdent)s;
        if (i)
            i.declaredBy.value = v;
        else
            assert(false, "value is not assignable");
        return v;
    }

    Exp visit (Closure sc) { return sc; }

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