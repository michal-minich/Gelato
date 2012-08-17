module ast;

import std.stdio, std.algorithm, std.array, std.conv;
import common, tokenizer, interpreter, formatter;


@safe:


mixin template visitImpl ()
{
    override dstring str (FormatVisitor v) { return v.visit(this); }
}


interface AstVisitor (R)
{
    R visit (AstNum);
    R visit (AstUnknown);
    R visit (AstFile);
    R visit (AstDeclr);
    R visit (AstStruct);
    R visit (AstFn);
    R visit (AstFnApply);
    R visit (AstIdent);
    R visit (AstLabel);
    R visit (AstReturn);
    R visit (AstText);
    R visit (AstChar);
    R visit (AstIf);
    R visit (AstGoto);
    R visit (AstLambda);
}


abstract class Exp
{
    Token[] tokens;
    Exp parent;
    Exp prev;
    Exp next;

    this (Exp parent, Exp prev)
    {
        this.parent = parent;
        this.prev = prev;
    }

    abstract dstring str (FormatVisitor v);
}


final class AstUnknown : Exp
{
    this (Exp parent, Exp prev) { super(parent, prev); }

    mixin visitImpl;
}


final class AstFile : Exp
{
    AstDeclr[] declarations;

    this (Exp parent, Exp prev, AstDeclr[] declrs)
    {
        super(parent, prev);
        declarations = declrs;
    }

    mixin visitImpl;
}


final class AstDeclr : Exp
{
    AstIdent ident;
    Exp type;
    Exp value;

    this (Exp parent, Exp prev, AstIdent identifier)
    {
        super(parent, prev);
        ident = identifier;
    }

    mixin visitImpl;
}


final class AstStruct : Exp
{
    AstDeclr[] declarations;

    this (Exp parent, Exp prev, AstDeclr[] declrs)
    {
        super(parent, prev);
        declarations = declrs;
    }

    mixin visitImpl;
}


final class AstIdent : Exp
{
    dstring[] idents;

    this (Exp parent, Exp prev, dstring[] identfiers)
    {
        super(parent, prev);
        idents = identfiers;
    }

    mixin visitImpl;
}


final class AstNum : Exp
{
    dstring value;

    this (Exp parent, Exp prev, dstring val)
    {
        super(parent, prev);
        value = val;
    }

    mixin visitImpl;
}


final class AstText : Exp
{
    dstring value;

    this (Exp parent, Exp prev, dstring val)
    {
        super(parent, prev);
        value = val;
    }

    mixin visitImpl;
}


final class AstChar : Exp
{
    dchar value;

    this (Exp parent, Exp prev, dchar val)
    {
        super(parent, prev);
        value = val;
    }

    mixin visitImpl;
}


final class AstLambda : Exp
{
    Interpreter.Env env;
    AstFn fn;

    this (Interpreter.Env e, AstFn f) { super (null, null); env = e; fn = f; }

    mixin visitImpl;
}


final class AstFn : Exp
{
    AstDeclr[] params;
    Exp[] fnItems;

    this (Exp parent, Exp prev) { super(parent, prev); }

    mixin visitImpl;
}


final class AstFnApply : Exp
{
    AstIdent ident;
    Exp[] args;

    this (Exp parent, Exp prev, AstIdent identifier)
    {
        super(parent, prev);
        ident = identifier;
    }

    mixin visitImpl;
}


final class AstIf : Exp
{
    Exp when;
    Exp[] then;
    Exp[] otherwise;

    this (Exp parent, Exp prev) { super(parent, prev); }

    mixin visitImpl;
}


final class AstLabel : Exp
{
    dstring label;

    this (Exp parent, Exp prev, dstring lbl)
    {
        super(parent, prev);
        label = lbl;
    }

    mixin visitImpl;
}


final class AstGoto : Exp
{
    dstring label;

    this (Exp parent, Exp prev, dstring lbl)
    {
        super(parent, prev);
        label = lbl;
    }

    mixin visitImpl;
}


final class AstReturn : Exp
{
    Exp exp;

    this (Exp parent, Exp prev) { super(parent, prev); }

    mixin visitImpl;
}