export initialize

function initialize(model;groups=[],expr="",parallel=false)
  var=match(r"^.*(?==)",expr).match
  value=match(r"(?<==).*",expr).match
  if !contains(model.initialization,var)
    N=model.groups[:N]
    if parallel==true
    model.initialization*="$var=SharedArray(Float64,N)\n"
    else
    model.initialization*="$var=zeros(N)\n"
    end
  end
  if groups==[] || groups=="all"
    model.initialization*="for i=1:N $var[i]=$value end\n"
  else
    for name in [groups;]
    i=model.groups[name]
    ii="(i-$(i[1]-1))"
    value=replace(value,"i",ii)
    model.initialization*="for i=$i $var[i]=$value end\n"
    end
  end
end 