export Connect

function Connect(model;pre=[],post=[],condition="true",expr="",parallel=false)
  var=match(r"^.*(?==)",expr).match
  value=match(r"(?<==).*",expr).match

  if !contains(model.connection,var)
    model.connection*="@parallel for p in workers()  @eval $var=zeros(N,N_tot) end\n"
  end

  for preTemp in [pre;],postTemp in [post;]
    j=model.groups[preTemp][:localindex]
    processor=model.groups[postTemp][:processor]
    condition=replace(condition,"j","(j-$(j[1]-1))")
    value=replace(value,"j","(j-$(j[1]-1))")
    model.connection*="""
    @spawnat $(processor+1) begin
      for j=$j,i=1:N
         if $condition
           $var[i,j]=$value
         end
      end
   end
   """
 end

end # end of function Connect
