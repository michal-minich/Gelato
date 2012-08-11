module parser;


import std.stdio, std.algorithm, std.array, std.conv;
import common, tokenizer, ast;
/*

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
        case "If": return astIf(ptExp);

        default:
            assert (false, to!string(ptExp.str));
    }
}


IExp astFnItem (ParseTree ptFnItem)
{
    assert (ptFnItem.ruleName == "FnItem");

    ptFnItem = ptFnItem.children[0];

    switch (ptFnItem.ruleName)
    {
        case "Exp": return astExp(ptFnItem);
        case "Declr": return astDeclr(ptFnItem);
        case "Label": return astLabel(ptFnItem);
        case "Goto": return astGoto(ptFnItem);
        case "Return": return astReturn(ptFnItem);

        default:
            assert (false, to!string(ptFnItem.str));
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
    if (ptFn.children.length == 0)
        return f;
    auto bodyIndex = 0;
    if (ptFn.children[0].ruleName == "FnParams")
    {
        f.params = astDeclrs(ptFn.children[0].children[0]);
        bodyIndex = 1;
    }
    if (ptFn.children.length == bodyIndex + 1)
        foreach (pt; ptFn.children[bodyIndex].children)
            f.fnItems ~= astFnItem(pt);
    return f;
}


AstFnApply astFnApply (ParseTree ptFnApply)
{
    assert (ptFnApply.ruleName == "FnApply");

    auto fna = new AstFnApply;
    fna.ident = astIdent(ptFnApply.children[0]);
    if (ptFnApply.children.length != 1)
        foreach (pt; ptFnApply.children[1].children)
            fna.args ~= astExp(pt);
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

*/