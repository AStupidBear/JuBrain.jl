export Connect

function Connect(model;pre=[],post=[],condition="true",expr="",parallel=false)
  var=match(r"^.*(?==)",expr).match
  value=match(r"(?<==).*",expr).match
  if !contains(model.connection,var)
    N=model.groups[:N]
    if parallel==true
    model.connection*="$var=SharedArray(Float64,N,N)\n"
    else
    model.connection*="$var=zeros(N,N)\n"
    end
  end

   if pre==[] || post==[]
      if parallel==true
      model.connection*="$var=SharedArray(Float64,(N,N),init=S->S[localindexes(S)]=$value)\n"
      else
      model.connection*="$var=fill($value,N,N)\n"
      end
  elseif pre=="all" && post=="all"
    model.connection*="for j=1:N\n for i=1:N\n if $condition\n $var[i,j]=$value\n end\n end\n end\n"
  elseif pre=="all" && post!="all"
    for postTemp in [post;]
      i=model.groups[postTemp]
      ii="(i-$(i[1]-1))"
      condition=replace(condition,"i",ii)
      value=replace(value,"i",ii)
      model.connection*="for j=1:N\n for i=$i\n if $condition\n $var[i,j]=$value\n end\n end\n end\n"
    end
  elseif pre!="all" && post=="all"
    for preTemp in [pre;]
      j=model.groups[preTemp]
      jj="(j-$(j[1]-1))"
      condition=replace(condition,"j",jj)
      value=replace(value,"j",jj)
      model.connection*="for j=$j\n for i=1:N\n if $condition\n $var[i,j]=$value\n end\n end\n end\n"
    end
  else
    for preTemp in [pre;],postTemp in [post;]
      i=model.groups[postTemp]
      j=model.groups[preTemp]
      ii="(i-$(i[1]-1))"
      jj="(j-$(j[1]-1))"
      condition=replace(condition,"i",ii);condition=replace(condition,"j",jj)
      value=replace(value,"i",ii);value=replace(value,"j",jj)
      model.connection*="for j=$j\n for i=$i\n if $condition\n $var[i,j]=$value\n end\n end\n end\n"
    end
  end
end # end of function Connect
