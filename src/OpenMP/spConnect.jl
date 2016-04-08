export spConnect

function spConnect(model;pre=[],post=[],expr="",p=0.1)
  var=match(r"^.*(?==)",expr).match
  value=match(r"(?<==).*",expr).match
  if !contains(model.connection,var)
    N=model.groups[:N]
    model.connection*="$var=spzeros(N,N)\n"
  end

  if pre==[] || post==[]
   model.connection*="$var[1:N,1:N]=$value*sprand(N,N,$p)\n"
  elseif pre=="all" && post=="all"
    model.connection*="$var[1:N,1:N]=$value*sprand(N,N,$p)\n"
  elseif pre=="all" && post!="all"
    for postTemp in [post;]
      i=model.groups[postTemp][:localindex]
      model.connection*="$var[$i,1:N]=$value*sprand($(length(i)),N,$p)\n"
    end
  elseif pre!="all" && post=="all"
    for preTemp in [pre;]
      j=model.groups[preTemp][:localindex]
      model.connection*="$var[1:N,$j]=$value*sprand(N,$(length(j)),$p)\n"
    end
  else
    for preTemp in [pre;],postTemp in [post;]
      i=model.groups[postTemp][:localindex]
      j=model.groups[preTemp][:localindex]
      model.connection*="$var[$i,$j]=$value*sprand($(length(i)),$(length(j)),$p)\n"
    end
  end

end # end of function spConnect