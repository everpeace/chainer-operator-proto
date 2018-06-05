{
  getHead(list):: if std.length(list) == 0 then
    {}
  else
    list[0],

  getKeyOrElse(obj, key, defaultValue)::
    if key in obj then
      obj[key]
    else
      defaultValue,
}
