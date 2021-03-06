module interpret.Interpreter;

import std.algorithm, std.array, std.conv;
import common, syntax.ast, validate.remarks, interpret.preparer, interpret.builtins, 
    interpret.NameFinder;



@safe final class Interpreter : IAstVisitor!Exp
{
    private
    {
        IInterpreterContext context;
        PreparerForEvaluator prep;
        Closure currentClosure;
        long gotoIndex = -1;
    } 


    this (IInterpreterContext icontext)
    {
        context = icontext;
        prep = new PreparerForEvaluator(icontext);
    }


    Exp evalLambda (Closure lambda)
    {
        auto exps = lambda.parent.exps;
        Exp lastExp;
        Exp e;
        uint expIndex;
        while (expIndex < exps.length)
        {
            currentClosure = lambda;
            lastExp = exps[expIndex];
            e = lastExp.eval(this);
            if (gotoIndex == typeof(gotoIndex).max - 1)
            {
                return e;
            }
            else if (gotoIndex == typeof(gotoIndex).max)
            {
                gotoIndex = -1;
                return e;
            }
            else if (gotoIndex != -1)
            {
                if (exps[expIndex].parent !is lambda.parent)
                    return null;

                expIndex = cast(uint)gotoIndex;
                gotoIndex = -1;
            }
            ++expIndex;
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
                if (bfn.func != &dbgExp)
                {
                    foreach (a; fna.args)
                        ea ~= a.eval(this);
                }
                else
                {
                    ea ~= fna.args[0];
                }
                
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

        auto lambda = new Closure(fn, currentClosure, fn.params);

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

        return evalLambda(lambda);
    }


    Exp visit (ExpIf i)
    {
        auto e = i.when.eval(this);
        auto isTrue = isTrueForIf(e);

        if (!isTrue && !i.otherwise)
        {
            return null;
        }
        else
        {
            auto fn = new ValueFn (currentClosure.parent);
            fn.exps = isTrue ? i.then.exps : i.otherwise.exps;
            return evalLambda(new Closure(fn, currentClosure, fn.params));
        }
    }


    static bool isTrueForIf (Exp e)
    {
        if (!e)
        throw new Exception ("if test expression must not evaluate to null.");

        auto when = cast(ValueInt)e;
        if (!when)
            throw new Exception ("if test expression must evaluate to number.");

        return when.value != 0;
    }


    Exp visit (ExpIdent ident)
    {
        auto d = ident.declaredBy;
        if (!d)
            return ValueUnknown.single;

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

       /* ??? auto st = cast(ValueStruct)record;
        if (!st)
        {
            context.except("struct must be constructed before accessing member ("
                           ~ dot.member.str(fv) ~ ")");
            return ValueUnknown.single;
        }*/

        auto sc = cast(Closure)record;
        if (!sc)
        {
            context.except("only struct can have members (" ~ dot.member.str(fv) ~ ")");
            return ValueUnknown.single;
        }
        
        foreach (ix, d; sc.declarations)
            if ((cast(ExpIdent)d.slot).text == dot.member.text)
                return sc.values[ix].eval(this);

                context.except("struct has no member " ~ dot.member.str(fv));

        return new ValueUnknown(null, dot.member);
    }


    @trusted Exp visit (StmReturn ret)
    {
        auto r = ret.exp.eval(this);
        gotoIndex = typeof(gotoIndex).max;
        return r;
    }


    @trusted Exp visit (StmGoto gt)
    {
        if (gt.labelExpIndex == typeof(gt.labelExpIndex).max)
            context.except("goto skipped because it has no matching label");
        else
            gotoIndex = gt.labelExpIndex;

        return null;
    }


    @trusted Exp visit (StmThrow th)
    {
        context.except("ex");
        gotoIndex = typeof(gotoIndex).max - 1;
        return null;
    }


    Exp visit (ExpAssign a)
    { 
        auto v = a.expValue ? a.expValue.eval(this) : null;
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

    Exp visit (ValueInt i) { return i; }

    Exp visit (ValueFloat f) { return f; }

    Exp visit (ValueBuiltinFn bfn) { return bfn; }

    Exp visit (ValueUnknown un) { return un; }

    Exp visit (ValueStruct s) { return s; }

    Exp visit (ValueArray arr) { return arr; }

    Exp visit (StmLabel) { return null; }

    Exp visit (StmImport) { return null; }

    Exp visit (TypeType) { return null; }

    Exp visit (TypeAny) { return null; }

    Exp visit (TypeVoid) { return null; }

    Exp visit (TypeAnyOf) { return null; }

    Exp visit (TypeFn) { return null; }

    Exp visit (TypeInt) { return null; }

    Exp visit (TypeFloat) { return null; }

    Exp visit (TypeText) { return null; }

    Exp visit (TypeChar) { return null; }

    Exp visit (TypeStruct) { return null; }

    Exp visit (TypeArray) { return null; }
}