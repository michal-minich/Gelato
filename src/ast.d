module parse.ast;

import std.conv;
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
    num,
    ident,
    op, dot, 
    coma,
    braceStart, braceEnd,
    textStart, text, textEscape, textEnd,
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
    R visit (ValueNum);
    R visit (ValueText);
    R visit (ValueChar);
    R visit (ValueStruct);
    R visit (ValueFn);
    R visit (ValueBuiltinFn);
    R visit (ValueUnknown);

    R visit (ExpIdent);
    R visit (ExpFnApply);
    R visit (ExpIf);
    R visit (ExpDot);
    R visit (ExpAssign);
    R visit (ExpLambda);
    R visit (ExpScope);

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
    R visit (TypeStruct);
}


alias IAstVisitor!(dstring) IFormatVisitor;


@system alias Exp function (IInterpreterContext, Exp[]) BuiltinFunc;


mixin template visitImpl ()
{
    override dstring str      (IFormatVisitor v)       { return v.visit(this); }
    override Exp     eval     (Evaluator v)            { return v.visit(this); }
    override void    prepare  (PreparerForEvaluator v) {        v.visit(this); }
    override void    validate (Validator v)            {        v.visit(this); }
    override Exp     infer    (TypeInferer v)          { return v.visit(this); }
}


abstract class Exp
{
    Exp infType;
    Token[] tokens;
    Exp parent;
    debug string typeName;

    this (Exp parent)
    {
        debug typeName = typeid(this).name;
        this.parent = parent; 
    }


    @trusted const pure @property tokensText ()
    {
        size_t l;
        foreach (t; tokens)
            l += t.text.length;

        auto s = new dchar[l];
        size_t rl;
        foreach (t; tokens)
        {
            s[rl .. rl + t.text.length] = t.text;
            rl += t.text.length;
        }
        return std.exception.assumeUnique(s);
    }


    abstract dstring str (IFormatVisitor);
    abstract Exp eval (Evaluator);
    abstract void prepare (PreparerForEvaluator);
    abstract void validate (Validator);
    abstract Exp infer (TypeInferer);
}


// =================================================== Values
final class ValueUnknown : Exp
{
    mixin visitImpl;
    this (Exp parent) { super(parent); }
}


final class ValueStruct : Exp
{
    mixin visitImpl;
    Exp[] exps;
    ValueFn constructor;
    this (Exp parent) { super(parent); }
}


final class ValueNum : Exp
{
    mixin visitImpl;
    long value;
    this (Exp parent, long value) { super(parent); this.value = value; }
}


final class ValueText : Exp
{
    mixin visitImpl;
    dstring value;
    this (Exp parent, dstring value) { super(parent); this.value = value; }
}


final class ValueChar : Exp
{
    mixin visitImpl;
    dchar value;
    this (Exp parent, dchar val)
    {
        super(parent);
        value = val;
    }
}


final class ValueFn : Exp
{
    mixin visitImpl;
    ExpAssign[] params;
    Exp[] exps;
    bool isPrepared;
    this (Exp parent) { super(parent); }
}


final class ValueBuiltinFn : Exp
{
    mixin visitImpl;
    TypeFn signature;
    BuiltinFunc func;
    this (BuiltinFunc func, TypeFn signature)
    {
        super (null);
        this.func = func;
        this.signature = signature;
    }
}


// =================================================== Expressions
final class ExpAssign : Exp
{
    mixin visitImpl;
    Exp slot;
    Exp type;
    Exp value;
    size_t paramIndex = typeof(paramIndex).max;
    this (Exp parent, Exp slot) { super(parent); this.slot = slot; }
}

class ExpScope : Exp
{
    mixin visitImpl;
    ExpAssign[] assigments;
    Exp[] values;
    this (ExpScope ps, ExpAssign[] declrs) { super (ps); assigments = declrs; }
}


final class ExpLambda : ExpScope
{
    mixin visitImpl;
    ValueFn fn;
    uint currentExpIndex;
    this (ExpScope ps, ValueFn fn) { super (ps, fn.params); this.fn = fn; }
}


final class ExpFnApply : Exp
{
    mixin visitImpl;
    Exp applicable;
    Exp[] args;
    this (Exp parent, Exp applicable, Exp[] args)
    {
        super(parent);
        this.applicable = applicable;
        this.args = args;
    }
}


final class ExpIdent : Exp
{
    mixin visitImpl;
    dstring text;
    ExpAssign declaredBy;
    this (Exp parent, dstring identfier) { super(parent); text = identfier; }
}


final class ExpIf : Exp
{
    mixin visitImpl;
    Exp when;
    Exp[] then;
    Exp[] otherwise;
    this (Exp parent) { super(parent); }
}


final class ExpDot : Exp
{
    mixin visitImpl;
    Exp record;
    dstring member;
    this (Exp parent, Exp record, dstring member)
    {
        super(parent);
        this.record = record;
        this.member = member;
    }
}


// =================================================== Statements
final class StmLabel : Exp
{
    mixin visitImpl;
    dstring label;
    this (Exp parent, dstring label) { super(parent); this.label = label; }
}


final class StmGoto : Exp
{
    mixin visitImpl;
    dstring label;
    uint labelExpIndex = uint.max;
    this (Exp parent, dstring label) { super(parent); this.label = label; }
}


final class StmReturn : Exp
{
    mixin visitImpl;
    Exp exp;
    this (Exp parent) { super(parent); }
}


// =================================================== Types
final class TypeType : Exp
{
    mixin visitImpl;
    Exp type;
    this (Exp parent, Exp type) { super(parent); this.type = type; }
}


final class TypeAny : Exp
{
    mixin visitImpl;
    this (Exp parent = null) { super(parent); }
}


final class TypeVoid : Exp
{
    mixin visitImpl;
    this (Exp parent = null) { super(parent); }
}


final class TypeOr : Exp
{
    mixin visitImpl;
    Exp[] types;
    this (Exp parent, Exp[] types) { super(parent); this.types = types; }
}


final class TypeFn : Exp
{
    mixin visitImpl;
    Exp[] types;
    Exp retType;
    this (Exp parent, Exp[] types, Exp retType)
    {
        super(parent);
        this.types = types;
        this.retType = retType;
    }
}


final class TypeStruct: Exp
{
    mixin visitImpl;
    Exp value;
    this (Exp parent, Exp value) { super(parent); this.value = value; }
}


final class TypeNum : Exp
{
    mixin visitImpl;
    this (Exp parent = null) { super(parent); }
}


final class TypeText : Exp
{
    mixin visitImpl;
    this (Exp parent = null) { super(parent); }
}


final class TypeChar: Exp
{
    mixin visitImpl;
    this (Exp parent = null) { super(parent); }
}