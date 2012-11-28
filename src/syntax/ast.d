module syntax.ast;

import std.conv, std.format, std.array;
import common;
import syntax.Formatter, syntax.SyntaxValidator, validate.TypeInferer, interpret.preparer, interpret.Interpreter, interpret.declrfinder;


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
        auto writer = appender!dstring(); 
        formattedWrite(writer, "%2s %-17s%2s:%s-%s(%s)%s  ", 
                       index, type, start.line, start.column, endColumn, text.length, pos);
        return writer.data ~ (isError ? "error"d : "     ") ~ "\t\"" ~ text.toVisibleCharsText() ~ "\"";
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
    op, dot, assign, asType,
    coma,
    braceStart, braceEnd,
    quote, textEscape,
    commentLine, commentMultiStart, commentMultiEnd,
    keyIf, keyThen, keyElse, keyEnd,
    keyFn, keyReturn,
    keyGoto, keyLabel,
    keyStruct,
    keyThrow,
    keyVar,
    keyImport,
    typeType, typeAny, typeVoid, typeOr, typeFn, typeInt, typeFloat, typeText, typeChar,
}


interface IAstVisitor (R)
{
    R visit (ValueInt);
    R visit (ValueFloat);
    R visit (ValueText);
    R visit (ValueChar);
    R visit (ValueStruct);
    R visit (ValueFn);
    R visit (ValueBuiltinFn);
    R visit (ValueUnknown);
    R visit (ValueArray);

    R visit (ExpIdent);
    R visit (ExpFnApply);
    R visit (ExpIf);
    R visit (ExpDot);
    R visit (ExpAssign);

    R visit (Closure);

    R visit (StmLabel);
    R visit (StmGoto);
    R visit (StmReturn);

    R visit (TypeType);
    R visit (TypeAny);
    R visit (TypeVoid);
    R visit (TypeOr);
    R visit (TypeFn);
    R visit (TypeInt);
    R visit (TypeFloat);
    R visit (TypeText);
    R visit (TypeChar);
    R visit (TypeStruct);
    R visit (TypeArray);

    R visit (WhiteSpace);
}


alias IAstVisitor!(dstring) IFormatVisitor;


@system alias Exp function (IInterpreterContext, Exp[]) BuiltinFunc;


mixin template visitImpl ()
{
    override dstring str       (IFormatVisitor v)       { return v.visit(this); }
    override Exp     eval      (Interpreter v)            { return v.visit(this); }
    override void    prepare   (PreparerForEvaluator v) {        v.visit(this); }
    override void    validate  (SyntaxValidator v)      {        v.visit(this); }
    override Exp     infer     (TypeInferer v)          { return v.visit(this); }
    override void    findDeclr (DeclrFinder v)          { return v.visit(this); }
}


abstract class Exp
{
    Exp infType;
    Token[] tokens;
    ValueScope parent;
    debug string typeName;


    this (ValueScope parent = null)
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
    abstract Exp eval (Interpreter);
    abstract void prepare (PreparerForEvaluator);
    abstract void validate (SyntaxValidator);
    abstract Exp infer (TypeInferer);
    abstract void findDeclr (DeclrFinder v);
}


// =================================================== Values
final class ValueUnknown : Exp
{
    mixin visitImpl;
    ExpIdent ident;
    nothrow this (ValueScope parent) { super(parent); }
    nothrow this (ValueScope parent, ExpIdent ident) { super(parent); this.ident = ident; }
    private this () { }
    static typeof(this) single;
    static this () { single = new typeof(this); }
}


final class ValueFloat : Exp
{
    mixin visitImpl;
    real value;
    nothrow this (ValueScope parent, real value) { super(parent); this.value = value; }
}


final class ValueInt : Exp
{
    mixin visitImpl;
    long value;
    nothrow this (ValueScope parent, long value) { super(parent); this.value = value; }
}


final class ValueText : Exp
{
    mixin visitImpl;
    dstring value;
    nothrow this (ValueScope parent, dstring value) { super(parent); this.value = value; }
}


final class ValueChar : Exp
{
    mixin visitImpl;
    dchar value;
    nothrow this (ValueScope parent, dchar val)
    {
        super(parent);
        value = val;
    }
}


abstract class ValueScope : Exp
{
    Exp[] exps;
    nothrow this (ValueScope parent) { super(parent); }
}


final class ValueStruct : ValueScope
{
    mixin visitImpl;
    ValueFn constructor;
    nothrow this (ValueScope parent) { super(parent); }
}


final class ValueArray : Exp
{
    mixin visitImpl;
    Exp[] items;
    nothrow this (ValueScope parent, Exp[] items)
    {
        super(parent);
        this.items = items;
    }
}


final class ValueFn : ValueScope
{
    mixin visitImpl;
    ExpAssign[] params;
    bool isPrepared;
    nothrow this (ValueScope parent) { super(parent); }
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
    Exp expValue;
    size_t paramIndex = typeof(paramIndex).max;
    ExpIdent[] usedBy;
    nothrow this (ValueScope parent, Exp slot, Exp value)
    {
        super(parent);
        this.slot = slot;
        this.expValue = value;
        this.value = value;
    }
}


final class ExpFnApply : Exp
{
    mixin visitImpl;
    Exp applicable;
    Exp[] args;
    nothrow this (ValueScope parent, Exp applicable, Exp[] args)
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
    size_t closureItemIndex;
    nothrow this (ValueScope parent, dstring identfier) { super(parent); text = identfier; }
}


final class ExpIf : Exp
{
    mixin visitImpl;
    Exp when;
    Exp[] then;
    Exp[] otherwise;
    nothrow this (ValueScope parent) { super(parent); }
}


final class ExpDot : Exp
{
    mixin visitImpl;
    Exp record;
    ExpIdent member;
    nothrow this (ValueScope parent, Exp record, ExpIdent member)
    {
        super(parent);
        this.record = record;
        this.member = member;
    }
}


// =================================================== Runtime Expressions
final class Closure : Exp
{
    mixin visitImpl;
    Closure closure;
    ExpAssign[] declarations;
    Exp[] values;
    nothrow this (ValueScope parent, Closure closure, ExpAssign[] declarations)
    {
        super (parent);
        this.closure = closure;
        this.declarations = declarations;
    }
}


// =================================================== Statements
final class StmLabel : Exp
{
    mixin visitImpl;
    dstring label;
    nothrow this (ValueScope parent, dstring label) { super(parent); this.label = label; }
}


final class StmGoto : Exp
{
    mixin visitImpl;
    dstring label;
    uint labelExpIndex = uint.max;
    nothrow this (ValueScope parent, dstring label) { super(parent); this.label = label; }
}


final class StmReturn : Exp
{
    mixin visitImpl;
    Exp exp;
    nothrow this (ValueScope parent, Exp exp) { super(parent); this.exp = exp; }
}


// =================================================== Types
final class TypeType : Exp
{
    mixin visitImpl;
    Exp type;
    nothrow this (ValueScope parent, Exp type) { super(parent); this.type = type; }
}


final class TypeAny : Exp
{
    mixin visitImpl;
    nothrow this (ValueScope parent) { super(parent); }
    static typeof(this) single;
    static this () { single = new typeof(this)(null); }
}


final class TypeVoid : Exp
{
    mixin visitImpl;
    nothrow this (ValueScope parent) { super(parent); }
    static typeof(this) single;
    static this () { single = new typeof(this)(null); }
}


final class TypeOr : Exp
{
    mixin visitImpl;
    Exp[] types;
    nothrow this (ValueScope parent, Exp[] types) { super(parent); this.types = types; }
}


final class TypeFn : Exp
{
    mixin visitImpl;
    Exp[] types;
    Exp retType;
    nothrow this (ValueScope parent, Exp[] types, Exp retType)
    {
        super(parent);
        this.types = types;
        this.retType = retType;
    }
}


final class TypeStruct: Exp
{
    mixin visitImpl;
    ValueStruct value;
    nothrow this (ValueScope parent, ValueStruct value) { super(parent); this.value = value; }
}


final class TypeInt : Exp
{
    mixin visitImpl;
    nothrow this (ValueScope parent) { super(parent); }
    static typeof(this) single;
    static this () { single = new typeof(this)(null); }
}


final class TypeFloat : Exp
{
    mixin visitImpl;
    nothrow this (ValueScope parent) { super(parent); }
    static typeof(this) single;
    static this () { single = new typeof(this)(null); }
}


final class TypeText : Exp
{
    mixin visitImpl;
    nothrow this (ValueScope parent) { super(parent); }
    static typeof(this) single;
    static this () { single = new typeof(this)(null); }
}


final class TypeChar: Exp
{
    mixin visitImpl;
    nothrow this (ValueScope parent) { super(parent); }
    static typeof(this) single;
    static this () { single = new typeof(this)(null); }
}


final class TypeArray: Exp
{
    mixin visitImpl;
    Exp elementType;
    nothrow this (ValueScope parent, Exp elementType) { super(parent); this.elementType = elementType; }
}


// =================================================== White
class WhiteSpace: Exp
{
    mixin visitImpl;
    nothrow this () { }
}


final class Comment: WhiteSpace
{
    mixin visitImpl;
    nothrow this () { }
}