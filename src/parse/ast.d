module parse.ast;

import std.stdio, std.algorithm, std.array, std.conv;
import common;
import formatter, validate.validation, interpret.preparer, interpret.evaluator;


@safe:
enum Geany { Bug }


struct Token
{
    uint index;
    TokenType type;
    Position start;
    dstring text;
    uint pos;
    bool isError;

    const @property nothrow size_t endColumn ()
    {
        return start.column + text.length - 1;
    }

    @trusted const dstring toDebugString ()
    {
        return dtext(index, "\t", type, "\t\t", start.line, ":", start.column, "-", endColumn,
               "(", text.length, ")", pos, "\t", isError ? "Error" : "",
               "\t\"", text.toVisibleCharsText(), "\"");
    }
}


struct Position
{
    uint line;
    uint column;
}


enum TokenType
{
    empty, unknown,
    white, newLine,
    num, ident, op,
    textStart, text, textEscape, textEnd,
    braceStart, braceEnd,
    commentLine, commentMultiStart, commentMulti, commentMultiEnd,
    keyIf, keyThen, keyElse, keyEnd,
    keyFn, keyReturn,
    keyGoto, keyLabel,
    keyStruct,
    keyThrow,
    keyVar,
}


mixin template visitImpl ()
{
    override dstring str (FormatVisitor v) { return v.visit(this); }

    override Exp eval (Evaluator v) { return v.visit(this); }

    override void prepare (PreparerForEvaluator v) { return v.visit(this); }

    override void validate (Validator v) { return v.visit(this); }
}


interface IAstVisitor (R)
{
    R visit (AstUnknown);

    R visit (AstNum);
    R visit (AstText);
    R visit (AstChar);
    R visit (AstFn);

    R visit (AstFnApply);
    R visit (AstLambda);

    R visit (AstIdent);
    R visit (AstDeclr);

    R visit (AstFile);
    R visit (AstStruct);

    R visit (AstLabel);
    R visit (AstGoto);
    R visit (AstReturn);
    R visit (AstIf);
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

    abstract dstring str (FormatVisitor);

    abstract Exp eval (Evaluator);

    abstract void prepare (PreparerForEvaluator);

    abstract void validate (Validator);
}


final class AstUnknown : Exp
{
    this (Exp parent, Exp prev) { super(parent, prev); }

    mixin visitImpl;
}


final class AstFile : Exp
{
    Exp[] exps;

    this () { super(null, null); }

    mixin visitImpl;
}


final class AstDeclr : Exp
{
    AstIdent ident;
    Exp type;
    Exp value;
    size_t paramIndex = typeof(paramIndex).max;

    this (Exp parent, Exp prev, AstIdent identifier)
    {
        super(parent, prev);
        ident = identifier;
    }

    mixin visitImpl;
}


final class AstStruct : Exp
{
    Exp[] exps;
    AstFn constructor;

    this (Exp parent, Exp prev) { super(parent, prev); }

    mixin visitImpl;
}


final class AstIdent : Exp
{
    dstring[] idents;
    AstDeclr declaredBy;

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
    AstFn fn;
    AstLambda parentLambda;
    uint currentExpIndex;
    AstDeclr[] evaledArgs;

    this (AstLambda pl, AstFn f) { super (null, null); parentLambda = pl; fn = f; }

    mixin visitImpl;
}


final class AstFn : Exp
{
    AstDeclr[] params;
    Exp[] exps;
    bool isPrepared;

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
    uint labelExpIndex = uint.max;

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