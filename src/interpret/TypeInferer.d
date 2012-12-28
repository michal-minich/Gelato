module interpret.TypeInferer;


import std.conv, std.algorithm, std.array;
import common, syntax.ast, syntax.Parser, validate.remarks, interpret.Interpreter, program;


@safe:


@trusted Exp mergeTypes (Exp[] types...)
{
    Exp[] possible;
    foreach (t; types)
        possible ~= flatternType(t);
    auto ts = possible.sort!typeIdLess().array().uniq!typeIdEq().array();
    return ts.length == 1 ? ts[0] : new TypeOr(null, ts);
}


@trusted bool typeIdLess (T) (T a, T b) { return &a < &b; }

// TODO optimize - then, the same function can be used for == and === built-in operators
@trusted bool typeIdEq (T) (T a, T b) { return a.str(fv) == b.str(fv); }


Exp[] flatternType(Exp t)
{
    Exp[] res;
    auto tOr = cast(TypeOr)t;
    if (tOr)
        foreach (t2; tOr.types)
            res ~= flatternType(t2);
    else
        res ~= t;

    return res;
}


final class TypeInferer : IAstVisitor!Exp
{
    private IInterpreterContext context;
    private ValueFn currentFn;
    Program program;
    ExpAssign structTypeAssign;
    uint structCounter;


    nothrow this (Program program, IInterpreterContext context) { this.program = program; this.context = context; }


    Exp visit (ValueUnknown u)
    {
        u.infType = TypeVoid.single;
        return u.infType;
    }


    Exp visit (ValueInt i)
    {
        i.infType = TypeInt.single;
        return i.infType;
    }


    Exp visit (ValueFloat f)
    {
        f.infType = TypeFloat.single;
        return f.infType;
    }


    Exp visit (ValueText t)
    {
        t.infType = TypeText.single;
        return t.infType;
    }


    Exp visit (ValueChar ch)
    {
        ch.infType = TypeChar.single;
        return ch.infType;
    }


    Exp visit (ValueArray arr)
    {
        structTypeAssign = null;

        assert (false, "value array infer");
    }


    Exp visit (ValueBuiltinFn bfn)
    {
        bfn.infType = bfn.signature;
        return bfn.signature;
    }


    Exp visit (ValueFn fn)
    {
        if (fn.infType)
            return fn.infType;

        structTypeAssign = null;

        inferFn(fn);

        return fn.infType;
    }


    TypeFn inferFn (ValueFn fn, Exp[] args = null)
    {
        Exp[] paramTypes;

        if (args)
        {
            foreach (ix, p; fn.params)
            {
                auto paramType = p.infer(this);
                if (cast(TypeAny)paramType)
                {
                    auto argType = args[ix].infer(this);
                    paramTypes ~= argType;
                    (cast(ExpIdent)p.slot).argType = argType;
                }
                else
                {
                    paramTypes ~= paramType;
                }
            }
        }
        else
        {
            foreach (p; fn.params)
                paramTypes ~= p.infer(this);
        }

        auto fnInfType = new TypeFn(null, paramTypes, TypeVoid.single, fn);
        fn.infType = fnInfType;

        foreach (e; fn.exps)
        {
            currentFn = fn;
            e.infer(this);
        }

        if (fn.exps.length == 1 && !cast(StmReturn)fn.exps[0])
            fnInfType.retType = fn.exps[0].infType;

        return fnInfType;
    }


    Exp visit (ExpFnApply fna)
    {
        structTypeAssign = null;

        Exp[] ts;
        foreach (a; fna.args)
            ts ~= a.infer(this);

        auto applicableType = fna.applicable.infer(this);
        auto tfn = cast(TypeFn)applicableType;

        if (tfn)
        {
            if (tfn.value)
                fna.infType = inferFn (tfn.value, fna.args).retType;
            else
                fna.infType = tfn.retType;
        }       
        else
        {
            fna.infType = (cast(TypeType)applicableType).type;
        }

        auto arrType = cast(TypeArray)fna.infType;
        if (arrType)
            arrType.elementType = mergeTypes(ts);

        return fna.infType;
    }


    Exp visit (ExpIdent i)
    {
        if (i.declaredBy)
        {
            auto s = cast(ExpIdent)i.declaredBy.slot;
            if (s && s.argType)
            {
                i.infType = s.argType;
                return i.infType;
            }
        }

        if (i.infType)
            return i.infType;

        structTypeAssign = null;

        i.infType = i.declaredBy && i.declaredBy.value
            ? i.declaredBy.value.infer(this)
            : TypeAny.single;

        return i.infType;
    }


    Exp visit (ExpAssign a)
    {
        if (a.infType)
            return a.infType;

        structTypeAssign = a;

        a.infType = a.value ? a.value.infer(this) : TypeAny.single;
        return a.infType;
    }


    @trusted Exp visit (ValueStruct s)
    {
        if (s.infType)
            return s.infType;

        if (!structTypeAssign)   
        {
            auto i = new ExpIdent(null, "AnynymousStruct_" ~ (++structCounter).to!dstring());
            structTypeAssign = new ExpAssign(null, i, s);
        }

        s.infType = new TypeType(null, new TypeStruct(null, structTypeAssign, s));

        foreach (e; s.exps)
            e.infer(this);

        return s.infType;
    }


    Exp visit (StmLabel l)
    {
        l.infType = TypeVoid.single;
        return l.infType;
    }


    Exp visit (StmGoto gt)
    {
        gt.infType = TypeVoid.single;
        return gt.infType;
    }


    @trusted Exp visit (StmReturn r)
    {
        auto fnRetType = &(cast(TypeFn)currentFn.infType).retType;
        auto infType = r.exp.infer(this);

        *fnRetType = cast(TypeVoid)*fnRetType
             ? infType
             : mergeTypes(*fnRetType, infType);

        r.infType = TypeVoid.single;
        return r.infType;
    }


    @trusted Exp visit (ExpIf i)
    {
        if (i.then.length == 1 && i.otherwise.length == 1)
        {
            auto t = mergeTypes(i.then[0].infer(this), i.otherwise[0].infer(this));
            auto tor = cast(TypeOr)t;
            if (tor)
            {
                i.infType = Interpreter.isTrueForIf(context.eval(i.when))
                   ? i.then[0].infType
                   : i.otherwise[0].infType;
            }
            else
            {
                i.infType = t;
            }
        }
        else
        {   
            foreach (t; i.then)
                t.infer(this);

            foreach (o; i.otherwise)
                o.infer(this);

            i.infType = TypeVoid.single;
        }

        return i.infType;
    }


    @trusted Exp visit (ExpDot dot)
    {
        if (dot.infType)
            return dot.infType;

        auto i2 = cast(ExpIdent)dot.record;
        if (i2)
        {
            auto dfna = cast(ExpFnApply)i2.declaredBy.value;
            if (dfna)
            {
                auto s2 = cast(ValueStruct)dfna.applicable;
                if (s2 && s2.filePath)
                {
                    auto astFile = program.loadFile(s2.filePath);
                    astFile.parent = s2.parent;
                    auto fna = new ExpFnApply(s2.parent, astFile, null);
                    s2.filePath = null;
                    i2.declaredBy.value = fna;
                }
            }
        }

        dot.record.infType = dot.record.infer(this);

        auto st = cast(TypeStruct)dot.record.infType;

        if (!st)
        {
            context.remark(textRemark("only struct can have members"));
            return TypeVoid.single;
        }

        foreach (m; st.value.exps)
        {
            auto a = cast(ExpAssign)m;
            auto i = cast(ExpIdent)a.slot;
            if (i.text == dot.member.text)
            {
                dot.member.declaredBy = a;
                a.usedBy ~= dot.member;
                dot.member.infType = i.infer(this);
                dot.infType = i.infType;
                return i.infType;
            }
        }

        context.remark(textRemark("member " ~ dot.member.str(fv) ~" is not defined"));
        return ValueUnknown.single;
    }


    Exp visit (Closure) { return ValueUnknown.single; }

    Exp visit (TypeType tt) { return new TypeType(null, tt); }

    Exp visit (TypeAny ta) { return new TypeType(null, ta); }

    Exp visit (TypeVoid tv) { return new TypeType(null, tv); }

    Exp visit (TypeOr tor) { return new TypeType(null, tor); }

    Exp visit (TypeFn tfn) { return new TypeType(null, tfn); }

    Exp visit (TypeInt ti) { return new TypeType(null, ti); }

    Exp visit (TypeFloat tf) { return new TypeType(null, tf); }

    Exp visit (TypeText tt) { return new TypeType(null, tt); }

    Exp visit (TypeChar tch) { return new TypeType(null, tch); }

    Exp visit (TypeStruct s) { return new TypeType(null, s); }

    Exp visit (TypeArray arr) { return new TypeType(null, arr); }

    Exp visit (WhiteSpace ws) { return null; }
}