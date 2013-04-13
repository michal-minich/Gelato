module test.DebugTokenFormater;


import std.array, std.algorithm;
import common, syntax.ast;


@trusted private dstring toVisibleCharsTextDbg (const dstring str)
{
    return str
        .replace("\n", "\x1F")
        .replace("\r", "\x11")
        .replace("    ", "\x1A")
        .replace(" ", "\x16");
}


@trusted pure final class DebugTokenFormater : IFormatVisitor
{   
    private uint level;   
    private uint maxLevel = 5;
    private enum dstring tabs = "    "d.replicate(16);
    bool printWaddings = true;
    bool printTokens = true;


    const private @property dstring tab(uint l = -1)
    {
        return '\n' ~ tabs[0 .. 2 * (l == -1 ? level : l)];
    }


    const private @property dstring bat(uint l = -1)
    {
        return tabs[0 .. 2 * (maxLevel - (l == -1 ? level : l))];
    }


    const private @property dstring ttw(Exp e)
    {
        auto t = ""d;
        if (printTokens)
            t = "\t\t\"" ~ e.tokensText.toVisibleCharsTextDbg() ~ '\"';

        return '|' ~  e.str(fv) ~ '|' ~ t ~ wad(e);
    }


    const private @property dstring wad(Exp e)
    {
        if (!printWaddings)
            return "";

        dstring s;

        foreach (w; e.waddings)
        {
            if (cast(WhiteSpace)w)
                s ~= tab(level + 1) ~ "WhiteSpace  ";
            else if (cast(Punctuation)w)
                s ~= tab(level + 1) ~ "Punctuation ";
            else if (cast(Comment)w)
                s ~= tab(level + 1) ~ "Comment     ";

            s ~=  bat ~ '|' ~ w.tokensText.toVisibleCharsTextDbg() ~ '|';
        }

        return s;
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
        return tab ~ "ExpAssign     " ~ bat ~ ttw(d) 
            ~ strExp(d.slot) ~ strExp(d.type) ~ strExp(d.value);
    }


    dstring visit (ValueStruct s)
    {
        return tab ~ "ValueStruct   " ~ bat ~ ttw(s) ~ strExps(s.exps);
    }


    dstring visit (ValueFn fn)
    {
        return tab ~ "ValueFn       " ~ bat ~ ttw(fn) ~ strExps(fn.params) ~ strExps(fn.exps);
    }

    dstring visit (ExpFnApply fna)
    {
        return tab ~ "ExpFnApply    " ~ bat ~ ttw(fna) ~ strExp(fna.applicable) ~ strExps(fna.args);
    }


    dstring visit (ExpIf i)
    {
        return tab ~ "ExpIf         " ~ bat ~ ttw(i) ~ strExp(i.when) ~ strExps(i.then.exps) 
            ~ strExps(i.otherwise.exps);
    }


    dstring visit (TypeAnyOf tao)
    {
        return tab ~ "TypeAnyOf     " ~ bat ~ ttw(tao) ~ strExps(tao.types);
    }


    dstring visit (StmReturn r)
    {
        return tab ~ "StmReturn     " ~ bat ~ ttw(r) ~ strExp(r.exp);
    }


    dstring visit (StmImport im)
    {
        return tab ~ "StmImport     " ~ bat ~ ttw(im) ~ strExp(im.exp);
    }


    dstring visit (StmThrow th)
    {
        return tab ~ "StmThrow      " ~ bat ~ ttw(th) ~ strExp(th.exp);
    }


    dstring visit (ExpDot dot)
    {
        return tab ~ "ExpDot        " ~ bat ~ ttw(dot) ~ strExp(dot.record) ~ strExp(dot.member);
    }


    const dstring visit (StmLabel l)
    {
        return tab ~ "StmLabel      " ~ bat ~ ttw(l) ~ (l.label ? l.label : "");
    }


    const dstring visit (StmGoto gt)
    {
        return tab ~ "StmGoto       " ~ bat ~ ttw(gt) ~ (gt.label ? gt.label : "");
    }


    const dstring visit (Closure c)          { return tab ~ "Closure       " ~ bat ~ ttw(c); }

    const dstring visit (ValueBuiltinFn bfn) { return tab ~ "ValueBuiltinFn" ~ bat ~ ttw(bfn); }

    const dstring visit (ValueInt i)         { return tab ~ "ValueInt      " ~ bat ~ ttw(i); }

    const dstring visit (ValueFloat f)       { return tab ~ "ValueFloat    " ~ bat ~ ttw(f); }

    const dstring visit (ValueUnknown u)     { return tab ~ "ValueUnknown  " ~ bat ~ ttw(u); }

    const dstring visit (ExpIdent i)         { return tab ~ "ExpIdent      " ~ bat ~ ttw(i); }

    const dstring visit (ValueText t)        { return tab ~ "ValueText     " ~ bat ~ ttw(t); }

    const dstring visit (ValueChar ch)       { return tab ~ "ValueChar     " ~ bat ~ ttw(ch); }

    const dstring visit (ValueArray arr)    { return tab ~ "ValueArray     " ~ bat ~ ttw(arr); }

    const dstring visit (TypeType tt)       { return tab ~ "TypeType       " ~ bat ~ ttw(tt); }

    const dstring visit (TypeAny ta)        { return tab ~ "TypeAny        " ~ bat ~ ttw(ta); }

    const dstring visit (TypeVoid tv)       { return tab ~ "TypeVoid       " ~ bat ~ ttw(tv); }

    const dstring visit (TypeInt ti)        { return tab ~ "TypeInt        " ~ bat ~ ttw(ti); }

    const dstring visit (TypeFloat tf)      { return tab ~ "TypeFloat      " ~ bat ~ ttw(tf); }

    const dstring visit (TypeText tt)       { return tab ~ "TypeText       " ~ bat ~ ttw(tt); }

    const dstring visit (TypeChar tch)      { return tab ~ "TypeChar       " ~ bat ~ ttw(tch); }

    const dstring visit (TypeStruct ts)     { return tab ~ "TypeStruct     " ~ bat ~ ttw(ts); }

    const dstring visit (TypeArray tarr)    { return tab ~ "TypeArray      " ~ bat ~ ttw(tarr); }

    const dstring visit (TypeFn tfn)        { return tab ~ "TypeFn         " ~ bat ~ ttw(tfn); }
}