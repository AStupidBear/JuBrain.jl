export Connect

function Connect(model;pre=[],post=[],condition="true",expr="")
  var=match(r"^.*(?==)",expr).match
  value=match(r"(?<==).*",expr).match
  if !contains(model.connection,var)
    N=model.groups[:N]
    model.connection*="$var=zeros(N,N)\n"
  end

   if pre==[] || post==[]
      model.connection*="$var=fill($value,N,N)\n"
  elseif pre=="all" && post=="all"
    model.connection*="for j=1:N\n for i=1:N\n if $condition\n $var[i,j]=$value\n end\n end\n end\n"
  elseif pre=="all" && post!="all"
    for postTemp in [post;]
      i=model.groups[postTemp][:localindex]
      ii="(i-$(i[1]-1))"
      condition=replace(condition,"i",ii)
      value=replace(value,"i",ii)
      model.connection*="for j=1:N\n for i=$i\n if $condition\n $var[i,j]=$value\n end\n end\n end\n"
    end
  elseif pre!="all" && post=="all"
    for preTemp in [pre;]
      j=model.groups[preTemp][:localindex]
      jj="(j-$(j[1]-1))"
      condition=replace(condition,"j",jj)
      value=replace(value,"j",jj)
      model.connection*="for j=$j\n for i=1:N\n if $condition\n $var[i,j]=$value\n end\n end\n end\n"
    end
  else
    for preTemp in [pre;],postTemp in [post;]
      i=model.groups[postTemp][:localindex]
      j=model.groups[preTemp][:localindex]
      ii="(i-$(i[1]-1))"
      jj="(j-$(j[1]-1))"
      condition=replace(condition,"i",ii);condition=replace(condition,"j",jj)
      value=replace(value,"i",ii);value=replace(value,"j",jj)
      model.connection*="for j=$j\n for i=$i\n if $condition\n $var[i,j]=$value\n end\n end\n end\n"
    end
  end
end # end of function Connect
