module test.DebugTokenFormater;


import std.array, std.algorithm;
import common, syntax.ast;


@trusted pure final class DebugTokenFormater : IFormatVisitor
{   
    private uint level;
    enum dstring tabs = "    "d.replicate(16);

    const private @property dstring tab() { return '\n' ~ tabs[0 .. 2 * level]; }

    const private @property dstring ttw(Exp e) { return "|" ~ e.tokensText.toVisibleCharsText() ~ wad(e); }


    const private @property dstring wad(Exp e)
    {
        return "|" ~ (e.wadding ? e.wadding.tokensText : "") ~ "|";
    }


    private dstring strExp(Exp e)
    {
        if (!e)
            return "";
        ++level;
        auto str = e.str(this);
        --level;
        return str;
    }


    private dstring strExps (T : Exp) (T[] es)
    {
        ++level;
        auto str = es.map!(e => e.str(this))().join();
        --level;
        return str;
    }


    dstring visit (ExpAssign d)
    {
        return tab ~ "ExpAssign\t\t" ~ ttw(d) ~ strExp(d.slot) ~ strExp(d.type) ~ strExp(d.value);
    }


    dstring visit (ValueStruct s)
    {
        return tab ~ "ValueStruct\t\t" ~ ttw(s) ~ strExps(s.exps);
    }


    dstring visit (ValueFn fn)
    {
        return tab ~ "ValueFn\t\t" ~ ttw(fn) ~ strExps(fn.params) ~ strExps(fn.exps);
    }

    dstring visit (ExpFnApply fna)
    {
        return tab ~ "ExpFnApply\t\t" ~ ttw(fna) ~ strExp(fna.applicable) ~ strExps(fna.args);
    }


    dstring visit (ExpIf i)
    {
        return tab ~ "ExpIf\t\t" ~ ttw(i) ~ strExp(i.when) ~ strExps(i.then.exps) ~ strExps(i.otherwise.exps);
    }


    dstring visit (TypeAnyOf tao)
    {
        return tab ~ "TypeAnyOf\t\t" ~ ttw(tao) ~ strExps(tao.types);
    }


    dstring visit (StmReturn r)
    {
        return tab ~ "StmReturn\t\t" ~ ttw(r) ~ strExp(r.exp);
    }


    dstring visit (StmImport im)
    {
        return tab ~ "StmImport\t\t" ~ ttw(im) ~ strExp(im.exp);
    }


    dstring visit (StmThrow th)
    {
        return tab ~ "StmThrow\t\t" ~ ttw(th) ~ strExp(th.exp);
    }


    dstring visit (ExpDot dot)
    { 
        return tab ~ "ExpDot\t\t" ~ ttw(dot) ~ strExp(dot.record) ~ strExp(dot.member);
    }


    const dstring visit (StmLabel l)
    {
        return tab ~ "StmLabel\t\t" ~ ttw(l) ~ (l.label ? l.label : "");
    }


    const dstring visit (StmGoto gt)
    {
        return tab ~ "StmGoto\t\t" ~ ttw(gt) ~ (gt.label ? gt.label : "");
    }


    const dstring visit (Closure c) { return tab ~ "Closure\t\t" ~ ttw(c); }

    const dstring visit (ValueBuiltinFn bfn) { return tab ~ "ValueBuiltinFn\t\t" ~ ttw(bfn); }

    const dstring visit (ValueInt i) { return tab ~ "ValueInt\t\t" ~ ttw(i); }

    const dstring visit (ValueFloat f) { return tab ~ "ValueFloat\t\t" ~ ttw(f); }

    const dstring visit (ValueUnknown u) { return tab ~ "ValueUnknown\t\t" ~ ttw(u); }

    const dstring visit (ExpIdent i) { return tab ~ "ExpIdent\t\t" ~ ttw(i); }

    const dstring visit (ValueText t){ return tab ~ "ValueText\t\t" ~ ttw(t); }

    const dstring visit (ValueChar ch) { return tab ~ "ValueChar\t\t" ~ ttw(ch); }

    const dstring visit (ValueArray arr) { return tab ~ "ValueArray\t\t" ~ ttw(arr); }

    const dstring visit (TypeType tt) { return tab ~ "TypeType\t\t" ~ ttw(tt); }

    const dstring visit (TypeAny ta) { return tab ~ "TypeAny\t\t" ~ ttw(ta); }

    const dstring visit (TypeVoid tv) { return tab ~ "TypeVoid\t\t" ~ ttw(tv); }

    const dstring visit (TypeInt ti) { return tab ~ "TypeInt\t\t" ~ ttw(ti); }

    const dstring visit (TypeFloat tf) { return tab ~ "TypeFloat\t\t" ~ ttw(tf); }

    const dstring visit (TypeText tt) { return tab ~ "TypeText\t\t" ~ ttw(tt); }

    const dstring visit (TypeChar tch) { return tab ~ "TypeChar\t\t" ~ ttw(tch); }

    const dstring visit (TypeStruct ts) { return tab ~ "TypeStruct\t\t" ~ ttw(ts); }

    const dstring visit (TypeArray tarr) { return tab ~ "TypeArray\t\t" ~ ttw(tarr); }

    const dstring visit (TypeFn tfn) { return tab ~ "TypeFn\t\t" ~ ttw(tfn); }
}