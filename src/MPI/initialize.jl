export initialize

function initialize(model;groups=[],expr="",parallel=false)
  var=match(r"^.*(?==)",expr).match
  value=match(r"(?<==).*",expr).match

  for name in [groups;]
    p=model.groups[name][:processor]
    model.initialization*="@spawnat $(p+1) @eval $var=[Float64($value) for i=1:N]\n"
  end
end
