export spConnect

function spConnect(model;pre=[],post=[],expr="",p=0.1)
  var=match(r"^.*(?==)",expr).match
  value=match(r"(?<==).*",expr).match

  if !contains(model.connection,var)
    model.connection*="@parallel for p in workers() @eval $var=spzeros(N,N_tot) end"
  end

  for preTemp in [pre;],postTemp in [post;]
    i=model.groups[postTemp][:localindex]
    j=model.groups[preTemp][:localindex]
    processor=model.groups[postTemp][:processor]
    model.connection*="@spawnat $(processor+1) $var[:,$j]=$value*sprand($(length(i)),$(length(j)),$p)\n"
  end
end # end of function spConnect
