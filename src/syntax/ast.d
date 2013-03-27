module syntax.ast;

import std.conv, std.format, std.array;
import common;
import syntax.Formatter, syntax.SyntaxValidator, interpret.TypeInferer, interpret.preparer, 
       interpret.Interpreter, interpret.NameFinder;


@safe:


struct Token
{
    uint index;
    TokenType type;
    Position start;
    dstring text;
    uint pos;

    const @property nothrow size_t endColumn ()
    {
        return start.column + text.length - 1;
    }

    @trusted const dstring toDebugString ()
    {
        auto writer = appender!dstring(); 
        formattedWrite(writer, "%2s %-17s%2s:%s-%s(%s)%s  ", 
                       index, type, start.line, start.column, endColumn, text.length, pos);
        return writer.data ~ "\"" ~ text.toVisibleCharsText() ~ "\"";
    }
}


struct Position
{
    uint line;
    uint column;
}

enum TokenType
{
    empty, error, unknown,
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
    keyImport, keyPublic, keyPackage, keyModule,
    typeType, typeVoid, typeAny, typeAnyOf, typeFn, typeInt, typeFloat, typeText, typeChar,
}


enum AccessScope
{
    scopePrivate,
    scopePublic = TokenType.keyPublic,
    scopePackage = TokenType.keyPackage,
    scopeModule = TokenType.keyModule
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
    R visit (StmThrow);
    R visit (StmReturn);
    R visit (StmImport);

    R visit (TypeType);
    R visit (TypeVoid);
    R visit (TypeAny);
    R visit (TypeAnyOf);
    R visit (TypeFn);
    R visit (TypeInt);
    R visit (TypeFloat);
    R visit (TypeText);
    R visit (TypeChar);
    R visit (TypeStruct);
    R visit (TypeArray);

    R visit (WhiteSpace);
}


interface INothrowAstVisitor (R)
{
    nothrow:

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
    R visit (StmThrow);
    R visit (StmReturn);
    R visit (StmImport);

    R visit (TypeType);
    R visit (TypeAny);
    R visit (TypeVoid);
    R visit (TypeAnyOf);
    R visit (TypeFn);
    R visit (TypeInt);
    R visit (TypeFloat);
    R visit (TypeText);
    R visit (TypeChar);
    R visit (TypeStruct);
    R visit (TypeArray);

    R visit (WhiteSpace);
}


alias IAstVisitor!dstring IFormatVisitor;


@system alias Exp function (IInterpreterContext, Exp[]) BuiltinFunc;


mixin template visitImpl ()
{
    override void         accept    (IAstVisitor!void v)     {        v.visit(this); }
    override dstring      str       (IFormatVisitor v)       { return v.visit(this); }
    override Exp          eval      (Interpreter v)          { return v.visit(this); }
    override Exp          infer     (TypeInferer v)          { return v.visit(this); }
    nothrow override void findName  (INothrowAstVisitor!void v)           { return v.visit(this); }
}


/*

    deterministic


assign + fn
    writesArg

var
    constant
*/


enum EffectValue { unknown, effector, allways, sometimes, never }
enum EffectValueNonPropagating { unknown, allways, never }


EffectValue escapes;
EffectValue writtenMoreThanOnce;
EffectValue linear;
EffectValue usedInReturn;


abstract class Exp
{
    Exp infType;
    Token[] tokens;
    ValueScope parent;

    EffectValueNonPropagating used; // propagates opposite direction

    EffectValue throws;
    EffectValue unsafe;
    EffectValue allocatesOnGC;
    EffectValue writesGlobal;
    EffectValue readsGlobal;
    EffectValue writesIO;
    EffectValue readsIO;

    debug string typeName;
    debug string dbgTokensText;


    nothrow this (ValueScope parent = null)
    {
        debug typeName = typeid(this).name;

        this.parent = parent;
    }


    nothrow @property void setTokens (Token[] ts)
    {
        tokens = ts;
        debug dbgTokensText = tokensText.toString();
    }


    nothrow @trusted const pure @property size_t tokensTextLength ()
    {
        size_t l;
        foreach (t; tokens)
            l += t.text.length;
        return l;
    }


    nothrow @trusted const pure @property dstring tokensText ()
    {
        auto s = new dchar[tokensTextLength];
        size_t rl;
        foreach (t; tokens)
        {
            s[rl .. rl + t.text.length] = t.text;
            rl += t.text.length;
        }
        return std.exception.assumeUnique(s);
    }


    abstract void accept (IAstVisitor!void);
    abstract dstring str (IFormatVisitor);
    abstract Exp eval (Interpreter);
    abstract Exp infer (TypeInferer);
    nothrow abstract void findName (INothrowAstVisitor!void);
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
    ExpAssign[dstring] declrs;
    size_t closureItemsCount;

    nothrow this (ValueScope parent) { super(parent); }

    nothrow ExpAssign get (ExpIdent i)
    {
        auto d = i.text in declrs;
        if (d)
        {
            d.writtenBy ~= i;
            return *d;
        }
        return parent ? parent.get(i) : null;
    }
}


final class ValueStruct : ValueScope
{
    mixin visitImpl;
    ValueFn constructor;
    bool isModule;
    string filePath;
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
    nothrow this (BuiltinFunc func, TypeFn signature)
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
    bool isVar;
    bool isDeclr;
    AccessScope accessScope;
    ExpIdent[] readBy;
    ExpIdent[] writtenBy;

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
    Exp argType;
    nothrow this (ValueScope parent, dstring identfier) { super(parent); text = identfier; }
}


final class ExpIf : Exp
{
    mixin visitImpl;
    Exp when;
    ValueScope then;
    ValueScope otherwise;
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
    StmGoto[] gotoBy;
    nothrow this (ValueScope parent, dstring label) { super(parent); this.label = label; }
}


final class StmGoto : Exp
{
    mixin visitImpl;
    dstring label;
    ulong labelExpIndex = ulong.max;
    nothrow this (ValueScope parent, dstring label) { super(parent); this.label = label; }
}


final class StmReturn : Exp
{
    mixin visitImpl;
    Exp exp;
    nothrow this (ValueScope parent, Exp exp) { super(parent); this.exp = exp; }
}


final class StmImport : Exp
{
    mixin visitImpl;
    Exp exp;
    nothrow this (ValueScope parent, Exp exp) { super(parent); this.exp = exp; }
}



final class StmThrow : Exp
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


final class TypeAnyOf : Exp
{
    mixin visitImpl;
    Exp[] types;
    nothrow this (ValueScope parent, Exp[] types) { super(parent); this.types = types; }
}


final class TypeFn : Exp
{
    mixin visitImpl;
    ValueFn value;
    Exp[] types;
    Exp retType;
    nothrow this (ValueScope parent, Exp[] types, Exp retType, ValueFn value = null)
    {
        super(parent);
        this.types = types;
        this.retType = retType;
        this.value = value;
    }
}


final class TypeStruct: Exp
{
    mixin visitImpl;
    ValueStruct value;
    ExpAssign typeAlias;
    nothrow this (ValueScope parent, ExpAssign typeAlias, ValueStruct value)
    { 
        super(parent);
        this.typeAlias = typeAlias;
        this.value = value;
    }
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