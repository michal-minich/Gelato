module ast;

import std.stdio, std.algorithm, std.array, std.conv;
import common, tokenizer, interpreter, formatter;


@safe:


enum Geany { Bug }


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


pure:


mixin template visitImpl ()
{
    dstring accept (FormatVisitor v) { return v.visit(this); }
}


interface IExp
{
    dstring accept (FormatVisitor v);
}


abstract class Exp : IExp
{
    Token[] tokens;
    Exp parent;
    Exp prev;
    Exp next;

    this (Token[] toks) { tokens = toks; }
}


final class AstUnknown : Exp
{
    this (Token[] toks) { super(toks); }

    mixin visitImpl;
}


final class AstFile : Exp
{
    AstDeclr[] declarations;

    this (Token[] toks, AstDeclr[] declrs)
    {
        super(toks);
        declarations = declrs;
    }

    mixin visitImpl;
}


final class AstDeclr : Exp
{
    AstIdent ident;
    Exp type;
    Exp value;

    this (Token[] toks, AstIdent identifier, Exp t, Exp val)
    {
        super(toks);
        ident = identifier;
        type = t;
        value = val;
    }

    mixin visitImpl;
}


final class AstStruct : Exp
{
    AstDeclr[] declarations;

    this (Token[] toks, AstDeclr[] declrs)
    {
        super(toks);
        declarations = declrs;
    }

    mixin visitImpl;
}


final class AstIdent : Exp
{
    dstring ident;

    this (Token[] toks, dstring identfier)
    {
        super(toks);
        ident = identfier;
    }

    mixin visitImpl;
}


final class AstNum : Exp
{
    dstring value;

    this (Token[] toks, dstring val)
    {
        super(toks);
        value = val;
    }

    mixin visitImpl;
}


final class AstText : Exp
{
    dstring value;

    this (Token[] toks, dstring val)
    {
        super(toks);
        value = val;
    }

    mixin visitImpl;
}


final class AstChar : Exp
{
    dchar value;

    this (Token[] toks, dchar val)
    {
        super(toks);
        value = val;
    }

    mixin visitImpl;
}


final class AstLambda : Exp
{
    Interpreter.Env env;
    AstFn fn;

    this (Interpreter.Env e, AstFn f) { super (null); env = e; fn = f; }

    mixin visitImpl;
}


final class AstFn : Exp
{
    AstDeclr[] params;
    Exp[] fnItems;

    this (Token[] toks, AstDeclr[] parameters, Exp[] funcItems)
    {
        super(toks);
        params = parameters;
        fnItems = funcItems;
    }

    mixin visitImpl;
}


final class AstFnApply : Exp
{
    AstIdent ident;
    Exp[] args;

    this (Token[] toks, AstIdent identifier, Exp[] arguments)
    {
        super(toks);
        ident = identifier;
        args = arguments;
    }

    mixin visitImpl;
}


final class AstIf : Exp
{
    Exp when;
    Exp[] then;
    Exp[] otherwise;

    this (Token[] toks, Exp w, Exp[] t, Exp[] o)
    {
        super(toks);
        when = w;
        then = t;
        otherwise = o;
    }

    mixin visitImpl;
}


final class AstLabel : Exp
{
    dstring label;

    this (Token[] toks, dstring lbl)
    {
        super(toks);
        label = lbl;
    }

    mixin visitImpl;
}


final class AstGoto : Exp
{
    dstring label;

    this (Token[] toks, dstring lbl)
    {
        super(toks);
        label = lbl;
    }

    mixin visitImpl;
}


final class AstReturn : Exp
{
    Exp exp;

    this (Token[] toks, Exp e)
    {
        super(toks);
        exp = e;
    }

    mixin visitImpl;
}