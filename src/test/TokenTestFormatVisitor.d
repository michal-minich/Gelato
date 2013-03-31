module test.TokenTestFormatVisitor;


import std.array, std.algorithm;
import syntax.ast;


@trusted pure final class TokenTestFormatVisitor : IFormatVisitor
{
    const dstring visit (ValueInt i) { return i.tokensText ~ "|"; }

    const dstring visit (ValueFloat f) { return f.tokensText ~ "|"; }

    const dstring visit (ValueUnknown e) { return e.tokensText ~ "|"; }

    dstring visit (ExpAssign d)
    { 
        return d.tokensText ~ "|" ~ d.slot.str(this)
            ~ (d.type ? d.type.str(this) : "") 
            ~ (d.value ? d.value.str(this) : "");
    }


    dstring visit (ValueStruct e) { return e.tokensText ~ "|" ~ e.exps.map!(e2 => e2.str(this))().join(); }


    dstring visit (ValueFn fn)
    { 
        return fn.tokensText ~ "|"
            ~ fn.params.map!(p => p.str(this))().join()
            ~ fn.exps.map!(e => e.str(this))().join();
    }

    dstring visit (ExpFnApply fna)
    { 
        return fna.tokensText ~ "|"
            ~ fna.applicable.str(this)
            ~ fna.args.map!(a => a.str(this))().join();
    }


    dstring visit (ExpIf i)
    {
        auto s = i.tokensText ~ "|" ~ i.when.str(this) ~ i.then.exps.map!(e => e.str(this))().join();
        
        if (i.otherwise.exps)
            s ~= i.otherwise.exps.map!(e => e.str(this))().join();

        return s;
    }


    const dstring visit (ExpIdent i) { return i.tokensText ~ "|"; }

    dstring visit (StmLabel e) { return e.tokensText ~ (e.label ? e.label : "") ~ "|"; }

    dstring visit (StmReturn e) { return e.tokensText ~ "|" ~ (e.exp ? e.exp.str(this) : ""); }

    dstring visit (StmImport im) { return im.tokensText ~ "|" ~ (im.exp ? im.exp.str(this) : ""); }

    dstring visit (StmThrow th) { return th.tokensText ~ "|" ~ (th.exp ? th.exp.str(this) : ""); }

    const dstring visit (ValueText e){ return e.tokensText ~ "|"; }

    const dstring visit (ValueChar e) { return e.tokensText ~ "|"; }

    const dstring visit (ValueArray e) { return e.tokensText ~ "|"; }

    const dstring visit (StmGoto e) { return e.tokensText ~ (e.label ? e.label : "") ~ "|"; }

    const dstring visit (Closure sc) { return sc.tokensText ~ "|"; }

    dstring visit (ExpDot dot) { return dot.tokensText ~ "|" ~ dot.record.str(this) ~ dot.member.str(this); }

    const dstring visit (TypeType tt) { return tt.tokensText ~ "|"; }

    const dstring visit (TypeAny ta) { return ta.tokensText ~ "|"; }

    const dstring visit (TypeVoid tv) { return tv.tokensText ~ "|"; }

    const dstring visit (TypeInt i) { return i.tokensText ~ "|"; }

    const dstring visit (TypeFloat f) { return f.tokensText ~ "|"; }

    const dstring visit (TypeText tt) { return tt.tokensText ~ "|"; }

    const dstring visit (TypeChar tch) { return tch.tokensText ~ "|"; }

    const dstring visit (TypeStruct ts) { return ts.tokensText ~ "|"; }

    const dstring visit (ValueBuiltinFn bfn) { return bfn.tokensText ~ "|"; }

    const dstring visit (TypeAnyOf tao) { return tao.tokensText ~ "|"; }

    const dstring visit (TypeArray arr) { return arr.tokensText ~ "|"; }

    const dstring visit (TypeFn tfn) { return tfn.tokensText ~ "|"; }
}