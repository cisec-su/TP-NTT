N=$1

n1=$2
n2=$3
n3=$4
n4=$5

TP=$6

choice=$7 # 0-->2D , 1-->3D , 2-->4D
q_size=$8

multiplier_type="word_level_mont"

script_dir=$(dirname "$(realpath "$0")")



if [ -z "$9" ]; then
    python_exe="python3"
else
    unset PYTHONHOME
    python_exe="$9"
fi

if [ -z "$10" ]; then
    verbose="1"
else
    verbose="$10"
fi


$python_exe "$script_dir/iterative_moduled_version.py" "$N" "$n1" "$n2" "$n3" "$n4" "$TP" "$7" "$q_size" "$script_dir" "$verbose"
$python_exe "$script_dir/tp_oriented_twiddle_model.py" "$N" 8 "$multiplier_type" "$q_size" "$script_dir"

