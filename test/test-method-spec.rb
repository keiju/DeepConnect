
require "class-spec-space"

Specs = [
  "method1_1()",
  "REF method1_2()",
  "REF, REF method1_3()",
  "REF, *VAL method1_4()",

  "method2_1(REF)",
  "REF method2_2(REF)",
  "REF, REF method2_3(REF)",
  "REF, *VAL method2_4(REF)",

  "method3_1(REF, *VAL)",
  "REF method3_2(REF, *VAL)",
  "REF, REF method3_3(REF, *VAL)",
  "REF, *VAL method3_4(REF, *VAL)",

  "method4_1() REF{}",
  "REF method4_2() REF{}",
  "REF, REF method4_3() REF{}",
  "REF, *VAL method4_4() REF{}",

  "method5_1() REF, *VAL{}",
  "REF method5_2() REF, *VAL{}",
  "REF, REF method5_3() REF, *VAL{}",
  "REF, *VAL method5_4() REF, *VAL{}",


  "method6_1(REF, *VAL) REF, *VAL{}",
  "REF method6_2(REF, *VAL) REF, *VAL{}",
  "REF, REF method6_3(REF, *VAL) REF, *VAL{}",
  "REF, *VAL method6_4(REF, *VAL) REF, *VAL{}",

  "method7_1(REF, *VAL){REF, *VAL}",
  "REF method7_2(REF, *VAL){REF, *VAL}",
  "REF, REF method7_3(REF, *VAL){REF, *VAL}",
  "REF, *VAL method7_4(REF, *VAL){REF, *VAL}",
  
  "method7_1(REF, *VAL) REF, *VAL{REF, *VAL}",
  "REF method7_2(REF, *VAL) REF, *VAL{REF, *VAL}",
  "REF, REF method7_3(REF, *VAL) REF, *VAL{REF, *VAL}",
  "REF, *VAL method7_4(REF, *VAL) REF, *VAL{REF, *VAL}",
]

for spec in Specs
  puts "PERSE: #{spec}"
  begin
    mspec = DeepConnect::MethodSpec.new
    mspec.parse(spec)
    puts "MethodSpec: #{mspec.to_s}"
#    puts "MethodSpec: #{mspec.inspect}"
    puts
  rescue
    puts "MethodSpec: #{mspec.to_s}"
    raise
  end
end

  
