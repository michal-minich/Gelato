module parse.ast;

import std.algorithm, std.array, std.conv;
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
    dot, coma, op,
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
    R visit (ExpDot);
    R visit (ExpScope);

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
    R visit (TypeStruct);
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


    abstract dstring str (FormatVisitor);

    abstract Exp eval (Evaluator);

    abstract void prepare (PreparerForEvaluator);

    abstract void validate (Validator);

    abstract Exp infer (TypeInferer);
}


@system alias Exp function (IInterpreterContext, Exp[]) BuiltinFunc;



final class AstUnknown : Exp
{
    this (Exp parent) { super(parent); }

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


final class TypeStruct: Exp
{
    Exp value;

    this (Exp value) { this(null, value); }

    this (Exp parent, Exp value) { super(parent); this.value = value; }

    mixin visitImpl;
}


final class ValueFile : Exp
{
    Exp[] exps;

    this () { super(null); }

    mixin visitImpl;
}


final class ValueStruct : Exp
{
    Exp[] exps;
    ValueFn constructor;

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class ValueNum : Exp
{
    long value;

    this (Exp parent, long val)
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


final class ValueFn : Exp
{
    StmDeclr[] params;
    Exp[] exps;
    bool isPrepared;

    this (Exp parent) { super(parent); }

    mixin visitImpl;
}


final class BuiltinFn : Exp
{
    TypeFn signature;
    BuiltinFunc func;

    this (BuiltinFunc func, TypeFn signature)
    {
        super (null);
        this.func = func;
        this.signature = signature;
    }

    mixin visitImpl;
}


class ExpScope : Exp
{
    StmDeclr[] declarations;
    Exp[] values;

    this (ExpScope ps, StmDeclr[] declrs) { super (ps); declarations = declrs; }

    mixin visitImpl;
}


final class ExpLambda : ExpScope
{
    ValueFn fn;
    uint currentExpIndex;

    this (ExpScope ps, ValueFn fn) { super (ps, fn.params); this.fn = fn; }

    mixin visitImpl;
}


final class ExpFnApply : Exp
{
    Exp applicable;
    Exp[] args;

    this (Exp parent, Exp applicable, Exp[] args)
    {
        super(parent);
        this.applicable = applicable;
        this.args = args;
    }

    mixin visitImpl;
}


final class ExpIdent : Exp
{
    dstring text;
    StmDeclr declaredBy;

    this (Exp parent, dstring identfier)
    {
        super(parent);
        text = identfier;
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


final class ExpDot : Exp
{
    Exp record;
    dstring member;

    this (Exp parent, Exp record, dstring member)
    {
        super(parent);
        this.record = record;
        this.member = member;
    }

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


final class StmDeclr : Exp
{
    Exp slot;
    Exp type;
    Exp value;
    size_t paramIndex = typeof(paramIndex).max;

    this (Exp parent, Exp slot) { super(parent); this.slot = slot; }

    mixin visitImpl;
}