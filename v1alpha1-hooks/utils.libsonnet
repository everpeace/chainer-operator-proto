{
  getHead(list):: if std.length(list) == 0 then
    {}
  else
    list[0],

  getHeadOrElse(list, defaultValue):: if std.length(list) == 0 then
    defaultValue
  else
    list[0],

}
