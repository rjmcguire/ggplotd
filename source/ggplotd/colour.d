module ggplotd.colour;

import std.range : ElementType;
import std.typecons : Tuple;

import cairo.cairo : RGB;

//import std.experimental.color.conv;
//import std.experimental.color.rgb;
//import std.experimental.color.hsx;

import ggplotd.aes : NumericLabel;

version(unittest)
{
    import dunit.toolkit;
}

// TODO build helper functions that returns a function 
// like below with to and from colours

auto colourGradient(R)( R colourIDs )
{
    import std.range : iota, enumerate, walkLength;
    RGB[ElementType!R] colourMap;
    auto values = iota( 0, 1, 1.0/colourIDs.walkLength );
    foreach( ref i, col; colourIDs.enumerate )
        colourMap[col] = 
            RGB(1.0, 0.0, 0 + values[i]);
    //RGB!("rgba", float)
    return (ElementType!R id)
    {
        return colourMap[id];
    };
}

unittest
{
    assertEqual(colourGradient(["a","b"])("a"), RGB(1,0,0));
    assertEqual(colourGradient(["a","b"])("b"), RGB(1,0,0.5));
}

/++
    Returns an associative array with names as key and colours as values

    Would have been nicer to just define a static AA, but that is currently
    not possible.
    +/
auto createNamedColours()
{
    RGB[string] nameMap;
    nameMap["black"] = RGB(0,0,0);
    nameMap["white"] = RGB(1,1,1);
    nameMap["red"] = RGB(1,0,0);
    nameMap["green"] = RGB(0,1,0);
    nameMap["red"] = RGB(0,0,1);
    return nameMap;
}

/// Converts any type into a double string pair, which is used by colour maps
struct ColourID
{
    import std.typecons : Tuple;

    ///
    this(T)( in T setId )
    {
        import std.math : isNumeric;
        import std.conv : to;
        static if (isNumeric!T)
        {
            id[0] = setId.to!double;
        }
        else 
            id[1] = setId.to!string;
    }

    Tuple!(double, string) id; ///

    alias id this; ///
}

unittest 
{
    import std.math : isNaN;
    import std.range : empty;
    auto cID = ColourID( "a" );
    assert( isNaN(cID[0]) );
    assertEqual( cID[1], "a" );
    auto numID = ColourID( 0 );
    assertEqual( numID[0], 0 );
    assert( numID[1].empty );
}

///
import std.range : isInputRange;
import std.range : ElementType;

struct ColourIDRange(T) if (isInputRange!T 
        && is( ElementType!T == ColourID ) )
{
    this( T range )
    {
        original = range;
        namedColours = createNamedColours();
    }

    @property auto front()
    {
        import std.range : front;
        import std.math : isNaN;
        if ( !isNaN(original.front[0]) || 
                original.front[1] in namedColours )
            return original.front;
        else if ( original.front[1] !in labelMap )
        {
            import std.conv : to;
            labelMap[original.front[1]] 
                = labelMap.length.to!double;
        }
        original.front[0] = labelMap[original.front[1]];
        return original.front;
    }

    void popFront()
    {
        import std.range : popFront;
        original.popFront;
    }

    @property bool empty()
    {
        import std.range : empty;
        return original.empty;
    }

    // TODO More elegant way of doing this? Key is that we want to keep
    // labelMap after our we've iterated over this array.
    // One possible solution would be to have a fillLabelMap, which will
    // run till the end of original and fill the LabelMap
    static double[string] labelMap;

    private:
        T original;
        //E[double] toLabelMap;
        RGB[string] namedColours;
}

unittest
{
    import std.math : isNaN;
    auto ids = [ColourID("black"), ColourID(-1),ColourID("a"),
        ColourID("b"), ColourID("a")];
    auto cids = ColourIDRange!(typeof(ids))( ids );

    assertEqual( cids.front[1], "black" );
    assert( isNaN( cids.front[0] ) );
    cids.popFront;
    assertEqual( cids.front[1], "" );
    assertEqual( cids.front[0], -1 );
    cids.popFront;
    assertEqual( cids.front[1], "a" );
    assertEqual( cids.front[0], 0 );
    cids.popFront;
    assertEqual( cids.front[1], "b" );
    assertEqual( cids.front[0], 1 );
    cids.popFront;
    assertEqual( cids.front[1], "a" );
    assertEqual( cids.front[0], 0 );
}

auto gradient( double value, double from, double till )
{
    return RGB( 1, 0, (value-from)/(till-from) );
}

private auto safeMax(T)( T a, T b )
{
    import std.math : isNaN;
    import std.algorithm : max;
    if (isNaN(b))
        return a;
    if (isNaN(a))
        return b;
    return max(a,b);
}

private auto safeMin(T)( T a, T b )
{
    import std.math : isNaN;
    import std.algorithm : min;
    if (isNaN(b))
        return a;
    if (isNaN(a))
        return b;
    return min(a,b);
}

auto createColourMap(R)( R colourIDs )
    if (is(ElementType!R == Tuple!(double, string)) ||
            is( ElementType!R == ColourID))
{
    import std.algorithm : filter, map, reduce;
    import std.math : isNaN;
    import std.array : array;
    import std.typecons : Tuple;

    auto validatedIDs = ColourIDRange!R( colourIDs );

    auto minmax = validatedIDs 
        .map!((a) => a[0])
        .reduce!((a,b)=>safeMin(a,b),(a,b)=>safeMax(a,b));

    auto namedColours = createNamedColours;
    //RGB!("rgba", float)
    return ( ColourID tup )
    {
        if (tup[1] in namedColours)
            return namedColours[tup[1]];
        else if (isNaN(tup[0]))
            return gradient(validatedIDs.labelMap[tup[1]]
                    ,minmax[0],minmax[1]);
        return gradient(tup[0],minmax[0],minmax[1]);
    };
}

unittest
{
    import std.typecons : Tuple;
    assertEqual(createColourMap([ColourID("a"),ColourID("b")])(
                ColourID("a")), RGB(1,0,0));
    assertEqual(createColourMap([ColourID("a"),ColourID("b")])(
                ColourID("b")), RGB(1,0,1));

    assertEqual(createColourMap([ColourID("a"),ColourID("b")])(
                ColourID("black")), RGB(0,0,0));

    assertEqual(createColourMap(
                [ColourID("black")] )(
                ColourID("black")), RGB(0,0,0));
}

