module ast;

import std.stdio, std.algorithm, std.array, std.conv;
import gel;

interface IAstItem
{
    string toString();
}

interface IExp : IAstItem
{

}

interface IFnItem : IAstItem
{

}


final class AstFile : IAstItem
{
    AstDeclr[] declarations;

    override string toString()
    {
        return declarations.map!(d => d.toString())().join("\r\n");
    }
}


final class AstDeclr : IFnItem
{
    AstIdent ident;
    IExp type;
    IExp value;

    override string toString()
    {
        if (type is null)
            return text (ident.toString(), " = ", value.toString());
        else if (value is null)
            return text (ident.toString(), " : ", type.toString());
        else
            return text (ident.toString(), " : ", type.toString(), " = ", value.toString());
    }
}


final class AstStruct : IExp
{
    AstDeclr[] declarations;

    override string toString()
    {
        return text("struct\r\n{\r\n\t", declarations.map!(d => d.toString())().join("\r\n\t"), "\r\n}");
    }
}


final class AstIdent : IExp
{
    string ident;

    override string toString()
    {
        return ident;
    }
}


final class AstNum : IExp
{
    string value;

    override string toString()
    {
        return value;
    }
}


final class AstText : IExp
{
    string value;

    override string toString()
    {
        return text("\"", toVisibleCharsText(value), "\"");
    }
}


final class AstChar : IExp
{
    dchar value;

    override string toString()
    {
        return text("'", toVisibleCharsChar(to!string(value)), "'");
    }
}


final class AstFn : IExp
{
    AstDeclr[] params;
    IFnItem[] exps;

    override string toString()
    {
        return text("fn (",
                    params.map!(p => p.toString())().join(", "),
                    ")\r\n{\r\n\t",
                    exps.map!(e => e.toString())().join("\r\n\t"),
                    "\r\n}");
    }
}


final class AstFnApply : IFnItem, IExp
{
    AstIdent ident;
    AstDeclr[] args;

    override string toString()
    {
        return text(ident, args.map!(a => a.toString())().join(", "), "(", ")");
    }
}


final class AstIf : IFnItem
{
    IExp when;
    IFnItem[] then;
    IFnItem[] otherwise;

    override string toString()
    {
        auto t = then.map!(th => th.toString())().join("\r\n\t");
        return otherwise.length == 0
            ? text("if ", when.toString(), " then ", t, " end")
            : text("if ", when.toString(), " then ", t, " else ",
                otherwise.map!(o => o.toString())().join("\r\n\t"), " end");
    }
}


final class AstLabel : IFnItem
{
    string label;

    override string toString()
    {
        return "label " ~ label;
    }
}


final class AstGoto : IFnItem
{
    string label;

    override string toString()
    {
        return "goto " ~ label;
    }
}


final class AstReturn : IFnItem
{
    IExp exp;

    override string toString()
    {
        return "return " ~ exp.toString();
    }
}


string toVisibleCharsText (string str)
{
    return str
        .replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t");
}


string toVisibleCharsChar (string str)
{
    return str
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t");
}


IAstItem astAll (ParseTree pt)
{
    writeln(pt);

    switch (pt.ruleName)
    {
        case "File": return astFile(pt);
        case "Declr": return astDeclr(pt);
        case "Exp": return astExp(pt);

        default:
            assert (false);
    }
}


IExp astExp (ParseTree ptExp)
{
    assert (ptExp.ruleName == "Exp");

    ptExp = ptExp.children[0];

    switch (ptExp.ruleName)
    {
        case "Ident": return astIdent(ptExp);
        case "Number": return astNum(ptExp);
        case "Text": return astText(ptExp);
        case "Char": return astChar(ptExp);
        case "Struct": return astStruct(ptExp);
        case "Fn": return astFn(ptExp);
        case "FnApply": return astFnApply(ptExp);

        default:
            assert (false, to!string(ptExp.toString()));
    }
}


IFnItem astFnItem (ParseTree ptFnItem)
{
    assert (ptFnItem.ruleName == "FnItem");

    ptFnItem = ptFnItem.children[0];

    switch (ptFnItem.ruleName)
    {
        case "Declr": return astDeclr(ptFnItem);
        case "FnApply": return astFnApply(ptFnItem);
        case "If": return astIf(ptFnItem);
        case "Label": return astLabel(ptFnItem);
        case "Goto": return astGoto(ptFnItem);
        case "Return": return astReturn(ptFnItem);

        default:
            assert (false, to!string(ptFnItem.toString()));
    }
}


AstFile astFile (ParseTree ptFile)
{
    assert (ptFile.ruleName == "File");

    auto f = new AstFile;
    f.declarations = astDeclrs(ptFile.children[0]);
    return f;
}


AstDeclr[] astDeclrs (ParseTree ptDeclrs)
{
    assert (ptDeclrs.ruleName == "Declrs");

    return ptDeclrs.children.map!(d => astDeclr(d))().array();
}


AstDeclr astDeclr (ParseTree ptDeclr)
{
    assert (ptDeclr.ruleName == "Declr");

    auto d = new AstDeclr;
    d.ident = astIdent(ptDeclr.children[0]);
    if (ptDeclr.capture[1] == ":")
    {
        d.type = astExp(ptDeclr.children[1]);
        if (ptDeclr.children.length == 3)
            d.value = astExp(ptDeclr.children[2]);
    }
    else
    {
       d.value = astExp(ptDeclr.children[1]);
    }
    return d;
}


AstStruct astStruct (ParseTree ptStruct)
{
    assert (ptStruct.ruleName == "Struct");

    auto s = new AstStruct;
    s.declarations = astDeclrs(ptStruct.children[0]);
    return s;
}


AstIdent astIdent (ParseTree ptIdent)
{
    assert (ptIdent.ruleName == "Ident");

    auto i = new AstIdent;
    i.ident = to!string(ptIdent.capture[0]);
    return i;
}


AstNum astNum (ParseTree ptNum)
{
    assert (ptNum.ruleName == "Number");

    auto n = new AstNum;
    n.value = to!string(ptNum.capture[0]);
    return n;
}


AstText astText (ParseTree ptText)
{
    assert (ptText.ruleName == "Text");

    auto t = new AstText;
    t.value = to!string(ptText.capture[0]
        .replace("\\n", "\n")
        .replace("\\r", "\r")
        .replace("\\t", "\t")
        .replace("\\\\", "\\"));
    return t;
}


AstChar astChar (ParseTree ptChar)
{
    assert (ptChar.ruleName == "Char");

    auto t = new AstChar;
    switch (ptChar.capture[0])
    {
        case "\\n": t.value = '\n'; break;
        case "\\r": t.value = '\r'; break;
        case "\\t": t.value = '\t'; break;
        default: t.value = ptChar.capture[0][0];
    }
    return t;
}


AstFn astFn (ParseTree ptFn)
{
    assert (ptFn.ruleName == "Fn");

    auto f = new AstFn;
    f.params = astDeclrs(ptFn.children[0].children[0]);
    foreach (pt; ptFn.children[1].children)
        f.exps ~= astFnItem(pt);
    return f;
}


AstFnApply astFnApply (ParseTree ptFnApply)
{
    assert (ptFnApply.ruleName == "FnApply");

    auto fna = new AstFnApply;
    fna.ident = astIdent(ptFnApply.children[0]);
    return fna;
}


AstIf astIf (ParseTree ptIf)
{
    assert (ptIf.ruleName == "If");
    auto i = new AstIf;
    i.when = astExp(ptIf.children[0]);
    foreach (pt; ptIf.children[1].children)
        i.then ~= astFnItem(pt);
    if (ptIf.children.length == 3)
        foreach (pt; ptIf.children[2].children)
            i.otherwise ~= astFnItem(pt);
    return i;
}


AstLabel astLabel (ParseTree ptLabel)
{
    assert (ptLabel.ruleName == "Label");

    auto l = new AstLabel;
    l.label = ptLabel.children[0].capture[0].to!string();
    return l;
}


AstGoto astGoto (ParseTree ptGoto)
{
    assert (ptGoto.ruleName == "Goto");

    auto g = new AstGoto;
    g.label = ptGoto.children[0].capture[0].to!string();
    return g;
}


AstReturn astReturn (ParseTree ptReturn)
{
    assert (ptReturn.ruleName == "Return");

    auto r = new AstReturn;
    r.exp = astExp(ptReturn.children[0]);
    return r;
}

