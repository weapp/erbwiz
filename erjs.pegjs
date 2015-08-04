{
  function makeInteger(o) {
    return parseInt(o.join(""), 10);
  }

  function build_options(pairs){
    obj = {};
    pairs.forEach(function(pair){
      obj[pair[0]] = pair[1]
    })
    return obj
  }

  function merge_options(obj1,obj2){
      var obj3 = {};
      ip_merge_options(obj3, obj1)
      ip_merge_options(obj3, obj2)
      return obj3;
  }

  function ip_merge_options(obj1,obj2){
      if (obj2) for (var attrname in obj2) { obj1[attrname] = obj2[attrname]; }
      return obj1;
  }

  function unshift(arr, elem){ arr.unshift(elem); return arr }

  function config(elem){
    elem = elem.value
    if (elem.key){
      key = elem.key
      delete elem.key
      el = {}
      for (k in elem)
        el['' + key + '.' + k] = elem[k]
      elem = el
    }
    return elem
  }

  function compress(arr){
    var ret = {CONFIG:{}, TABLE:[], REL:[], SAME:[]};
    arr.forEach(function(elem){
      var list = ret[elem.type];
      if (elem.type == 'CONFIG'){
        return ip_merge_options(list, config(elem));
      }
      delete elem.type
      list.push(elem);
    })
    return ret;
  }
}

start = instructions

instructions = nl? s data:(config / same / relation / table )* { return compress(data) }

config = config:dict nl? { return {type: "CONFIG", value:config} }
       / config:pairs nl? { return {type: "CONFIG", value:config} }

table = header:header fields:field*
        { return {type: "TABLE", header:header, fields:fields} }

header = label:label opts:options (nl / EOF)
         { return {label:label, options:opts} }

field = s m1:asterisk? ident:identifier m2:asterisk? opts:options (nl / EOF)
        { return {text:ident, pk:!!m1, fk:!!m2, options:opts} }

asterisk = [*]

relation = s r1:label s rel:arrow s r2:label opts:options (nl / EOF)
           { return {type:"REL", node1: r1, rel:rel.trim(), node2:r2, options:opts} }

// arrow = $([^[\n]+)
arrow = $(![[(\n] .)+
//arrow = $(. ([-][-] / [.][.] / [=][=] / [/][/]) .)
// [-.=/*+1<>?]

same = s table:label tables:another_same+ opts:options (nl / EOF)
       { return {type: "SAME", tables: unshift(tables, table), options:opts} }

options = mark:mark? dict:dict? { return merge_options(dict, mark) }

another_same = s [=][=] s ret:label { return ret }

dict = s [{] s [}] { return [] }
      / s [{] nl? ret:pairs s [}] { return ret }

pairs = pair:pair pairs:(another_pair)* s [;,]?
        nl? { return build_options(unshift(pairs, pair)) }

mark = s [<][-] mark:$[^<>-]+ [-][>] { return { mark: '<' + mark + '>' } }
     / s [<][-] mark:$[^<>-]+ [>]    { return { mark: '<' + mark + ']' } }
     / s [<] mark:$[^<>-]+ [-][>]    { return { mark: '[' + mark + '>' } }
     / s [<] mark:$[^<>-]+ [>]       { return { mark: mark } }
     / s [<][<] mark:$[^<>]+ [>][>]  { return { mark: '<' + mark + '>' } }

another_pair = (nl / [;,])? ret:pair { return ret }

pair = s k:$(word([.]word)*) s [:=] s v:dict_value s { return [k, v] }

dict_key = word

dict_value = string_value
           / numeric_value
           / $(word/[<>])+
           / [:]ret:word { return ret }

string_value = $(["] [^"]* ["]) / $(['] [^']* ['])

numeric_value = $([0-9]*.)?[0-9]+

//label = [\[] ident:$(identifier/[<>❝❞: ;|+()!]/label)+ dict? [\]] { return ident }
//      / [\(] ident:$(identifier/[<>❝❞: ;|+()!]/label)+ dict? [\)] { return ident }

label = [\[] ret:$([^[-\]]/label)+ dict? [\]] { return ret }
      / [\(] ret:$([^(-\)]/label)+ dict? [\)] { return ret }


identifier = $(word (s word)*)

word = $[a-zA-Z0-9-_]+

s = [ ]*

nl = ([ ]* comment [\n])+

comment = ([#][^\n]*)?

EOF = !.
