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

interface IStm : IAstItem
{

}

final class AstFile : IStm
{
    AstDeclr[] declarations;

    override string toString()
    {
        return declarations.map!(d => d.toString()).join("\r\n");
    }
}

final class AstDeclr : IStm
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

final class AstStruct : IStm
{
    override string toString()
    {
        return "struct";
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

IAstItem astAll (ParseTree pt)
{
    writeln(pt);

    switch (pt.ruleName)
    {
        case "File": return astFile(pt);
        case "Declr": return astDeclr(pt);
        case "Exp": return astExp(pt);
        case "Struct": return astStruct(pt);

        default:
            assert (false);
    }
}

IExp astExp (ParseTree ptExp)
{
    switch (ptExp.children[0].ruleName)
    {
        case "Ident": return astIdent(ptExp);
        case "Number": return astNum(ptExp);

        default:
            assert (false, to!string(ptExp.toString()));
    }
}


AstFile astFile (ParseTree ptFile)
{
    auto f = new AstFile ();
    foreach (ptDeclr; ptFile.children[0].children)
        f.declarations ~= astDeclr(ptDeclr);
    return f;
}

AstDeclr astDeclr (ParseTree ptDeclr)
{
    auto d = new AstDeclr ();
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


AstStruct astStruct (ParseTree ptDeclrItem)
{
    auto s = new AstStruct;
    return s;
}


AstIdent astIdent (ParseTree ptIdent)
{
    auto i = new AstIdent;
    i.ident = to!string(ptIdent.capture[0]);
    return i;
}


AstNum astNum (ParseTree ptNum)
{
    auto n = new AstNum;
    n.value = to!string(ptNum.capture[0]);
    return n;
}

