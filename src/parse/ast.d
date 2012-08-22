module parse.ast;

import std.stdio, std.algorithm, std.array, std.conv;
import common;
import formatter, validate.validation, validate.inferer, interpret.preparer, interpret.evaluator;


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
    typeType, typeAny, typeVoid, typeOr, typeFn, typeNum, typeText, typeChar,
}


interface IAstVisitor (R)
{
    R visit (AstUnknown);

    R visit (ValueNum);
    R visit (ValueText);
    R visit (ValueChar);
    R visit (ValueFile);
    R visit (ValueStruct);
    R visit (ValueFn);
    R visit (BuiltinFn);

    R visit (ExpIdent);
    R visit (ExpFnApply);
    R visit (ExpLambda);
    R visit (ExpIf);

    R visit (StmDeclr);
    R visit (StmLabel);
    R visit (StmGoto);
    R visit (StmReturn);

    R visit (TypeType);
    R visit (TypeAny);
    R visit (TypeVoid);
    R visit (TypeOr);
    R visit (TypeFn);
    R visit (TypeNum);
    R visit (TypeText);
    R visit (TypeChar);
}


mixin template visitImpl ()
{
    override dstring str (FormatVisitor v) { return v.visit(this); }

    override Exp eval (Evaluator v) { return v.visit(this); }

    override void prepare (PreparerForEvaluator v) { return v.visit(this); }

    override void validate (Validator v) { return v.visit(this); }

    override Exp infer (TypeInferer v) { return v.visit(this); }
}


abstract class Exp
{
    Exp infType;
    Token[] tokens;
    Exp parent;

    this (Exp parent) { this.parent = parent; }

    abstract dstring str (FormatVisitor);

    abstract Exp eval (Evaluator);

    abstract void prepare (PreparerForEvaluator);

    abstract void validate (Validator);

    abstract Exp infer (TypeInferer);
}


@system alias Exp function (IInterpreterContext, Exp[]) BuiltinFunc;


final class BuiltinFn : Exp
{
    dstring name;
    TypeFn signature;
    BuiltinFunc func;

    this (dstring name, BuiltinFunc func, TypeFn signature)
    {
        super (null);
        this.name = name;
        this.func = func;
        this.signature = signature;
    }

    mixin visitImpl;
}


final class TypeType : Exp
{
    Exp type;

    this (Exp parent, Exp type) { super(parent); this.type = type; }

    mixin visitImpl;
}


final class TypeAny : Exp
{
    this () { super(null); }

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class TypeVoid : Exp
{
    this () { super(null); }

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class TypeOr : Exp
{
    Exp[] types;

    this (Exp[] types) { this(null, types);  }

    this (Exp parent, Exp[] types) { super(parent); this.types = types; }

    mixin visitImpl;
}


final class TypeFn : Exp
{
    Exp[] types;
    Exp retType;

    this (Exp[] types) { this(null, types, null);  }

    this (Exp[] types, Exp retType) { this(null, types, retType); }

    this (Exp parent, Exp[] types, Exp retType)
    {
        super(parent);
        this.types = types;
        this.retType = retType;
    }

    mixin visitImpl;
}


final class TypeNum : Exp
{
    this () { super(null); }

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class TypeText : Exp
{
    this () { super(null); }

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class TypeChar: Exp
{
    this () { super(null); }

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class AstUnknown : Exp
{
    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class ValueFile : Exp
{
    Exp[] exps;

    this () { super(null); }

    mixin visitImpl;
}


final class StmDeclr : Exp
{
    ExpIdent ident;
    Exp type;
    Exp value;
    size_t paramIndex = typeof(paramIndex).max;

    this (Exp parent, ExpIdent identifier)
    {
        super(parent);
        ident = identifier;
    }

    mixin visitImpl;
}


final class ValueStruct : Exp
{
    Exp[] exps;
    ValueFn constructor;

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class ExpIdent : Exp
{
    dstring[] idents;
    StmDeclr declaredBy;

    this (Exp parent, dstring[] identfiers)
    {
        super(parent);
        idents = identfiers;
    }

    mixin visitImpl;
}


final class ValueNum : Exp
{
    dstring value;

    this (Exp parent, dstring val)
    {
        super(parent);
        value = val;
    }

    mixin visitImpl;
}


final class ValueText : Exp
{
    dstring value;

    this (Exp parent, dstring val)
    {
        super(parent);
        value = val;
    }

    mixin visitImpl;
}


final class ValueChar : Exp
{
    dchar value;

    this (Exp parent, dchar val)
    {
        super(parent);
        value = val;
    }

    mixin visitImpl;
}


final class ExpLambda : Exp
{
    ValueFn fn;
    ExpLambda parentLambda;
    uint currentExpIndex;
    StmDeclr[] evaledArgs;

    this (ExpLambda pl, ValueFn f) { super (null); parentLambda = pl; fn = f; }

    mixin visitImpl;
}


final class ValueFn : Exp
{
    StmDeclr[] params;
    Exp[] exps;
    bool isPrepared;

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class ExpFnApply : Exp
{
    ExpIdent ident;
    Exp[] args;

    this (Exp parent, ExpIdent identifier)
    {
        super(parent);
        ident = identifier;
    }

    mixin visitImpl;
}


final class ExpIf : Exp
{
    Exp when;
    Exp[] then;
    Exp[] otherwise;

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class StmLabel : Exp
{
    dstring label;

    this (Exp parent, dstring lbl)
    {
        super(parent);
        label = lbl;
    }

    mixin visitImpl;
}


final class StmGoto : Exp
{
    dstring label;
    uint labelExpIndex = uint.max;

    this (Exp parent, dstring lbl)
    {
        super(parent);
        label = lbl;
    }

    mixin visitImpl;
}


final class StmReturn : Exp
{
    Exp exp;

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}