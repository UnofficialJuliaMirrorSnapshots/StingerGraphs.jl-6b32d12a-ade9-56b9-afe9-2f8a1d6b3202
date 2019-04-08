import Base: getindex, setindex!
export get_nv, getvertex, edgeparse, StingerEdge, StingerVertex

"""
    getindex(x::Stinger, field::StingerFields)

Obtain value of a field from the Stinger data structure.
For `batch_time` and `update_time`, use `get_batchtime`
and `get_updatetime` respectively.
"""
function getindex(x::Stinger, field::StingerFields)
    idx = Int(field)
    if field == batch_time || field == update_time
        error("For $field use get_$field()")
    end
    basepointer = convert(Ptr{Int64}, x.handle)
    unsafe_load(basepointer, idx)
end

function get_batchtime(x::Stinger)
    basepointer = convert(Ptr{Float64}, x.handle)
    unsafe_load(basepointer, Int(batch_time))
end

function get_updatetime(x::Stinger)
    basepointer = convert(Ptr{Float64}, x.handle)
    unsafe_load(basepointer, Int(update_time))
end

"""
    setindex!(x::Stinger, val, field::StingerFields)

Set value of a field from the Stinger data structure.
"""
function setindex!(x::Stinger, val, field::StingerFields)
    idx = Int(field)
    ftype = fieldtype(StingerGraph, idx)
    @assert isa(val, ftype)
    basepointer = convert(Ptr{ftype}, x.handle)
    unsafe_store!(basepointer,val,idx)
end

"""
    get_nv(x::Stinger)

Returns number of active vertices in the graph. This is based on the largest
vertex ID which has a non-zero indegree or outdegree.
"""
function get_nv(x::Stinger)
    nv = ccall(
        dlsym(stinger_core_lib, "stinger_max_active_vertex"),
        Int64,
        (Ptr{Void},),
        x
    )
    nv==0 && return nv
    nv+1
end

"""
    storageptr(s::Stinger)

Get a pointer to the storage array of the STINGER data structure
"""
storageptr(s::Stinger) = s.handle + sizeof(StingerGraph) + 5*sizeof(UInt64)

"""
The STINGER Vertex representation.
"""
immutable StingerVertex
    vtype::Int64
    weight::Int64
    indegree::Int64
    outdegree::Int64
    degree::Int64
    edges::Int64
end

const NUMEDGEBLOCKS = 14

"""
The STINGER Edge representation.
"""
immutable StingerEdge
    neighbor::Int64
    weight::Int64
    timefirst::Int64
    timerecent::Int64
end

immutable StingerEdgeBlock
    next::UInt64
    etype::Int64
    vertexid::Int64
    numedges::Int64
    high::Int64
    smallstamp::Int64
    largestamp::Int64
    cache_pad::Int64
end

"""
    edgeparse(edge::StingerEdge)

Parse the direction and neighbor given a `StingerEdge`.
The first 2 bits of the `neighbor` field of the edge denotes the direction.
1 - in, 2 - out, 3 - both
"""
function edgeparse(edge::StingerEdge)
    direction = edge.neighbor >> 61 #The first 2 bits denote the direction, 1 - in, 2 - out, 3 - both
    neighbor = ~(7 << 61) & edge.neighbor
    return direction, neighbor
end

"""
    getvertex(s::Stinger, v::Int64)

Load the specified vertex from the STINGER datastructure.
"""
function getvertex(s::Stinger, v::Int64)
    vertices = convert(Ptr{StingerVertex}, storageptr(s) + sizeof(Int64)) #Read the StingerVertex array
    vertex = unsafe_load(vertices, v+1)
    vertex
end

function getvertexedgesoffset(s::Stinger, v::Int64)
    vertex = stinger_vertex_get(s,v)
    vertex.edges
end
