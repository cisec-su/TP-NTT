N=$1

n1=$2
n2=$3
n3=$4
n4=$5

TP=$6

choice=$7 # 0-->4-step , 1-->6-step , 2--> 7-step
q_size=$8

multiplier_type="word_level_mont"

python3 "tp_oriented_twiddle_model.py" "$N" 8 "$multiplier_type" "$q_size"
python3 "iterative_moduled_version.py" "$N" "$n1" "$n2" "$n3" "$n4" "$TP" "$7" "$q_size"
