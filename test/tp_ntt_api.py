def create_unique_twiddles(psi, N, TP ,q, test_dir, intt):    

    if not intt:
        input_path = f"{test_dir}/psi.txt"
        output_path = f"{test_dir}/psi_unique.txt"

        with open(input_path, "r") as infile:
            infile.seek(0)
            lines = infile.readlines()

        seen = set()
        unique_lines = []

        for line in lines:
            # Skip empty lines (optional)
            if line and line not in seen:
                seen.add(line)
                unique_lines.append(line)

        needs_to_add = []
        
        for unique_ln in unique_lines[N//TP:]:
            unique_ln_split = (unique_ln.strip("\t\n")).split("\t")
            for elm in unique_ln_split:
                needs_to_add.append(elm)

        ctr = 0
        with open(output_path, "w") as outfile:
            for line in unique_lines[:(N//TP)]:
                ln_split = (line.strip("\t\n")).split("\t")
                for i in range(TP-len(ln_split)):
                    if ctr < len(needs_to_add):
                        ln_split.append(needs_to_add[ctr])
                        ctr = ctr + 1
                
                write_line = ""
                for elm in ln_split:
                    write_line = write_line + elm + "\t"
                write_line = write_line + "\n"
                outfile.write(write_line)
    else:
        input_path = f"{test_dir}/psi_inv.txt"
        output_path = f"{test_dir}/psi_inv_unique.txt"

        with open(input_path, "r") as infile:
            infile.seek(0)
            lines = infile.readlines()

        seen = set()
        unique_lines = []

        for line in lines:
            # Skip empty lines (optional)
            if line and line not in seen:
                seen.add(line)
                unique_lines.append(line)

        needs_to_add = []
        set_needs_to_add = []
        
        for unique_ln in unique_lines[(N//TP):]:
            unique_ln_split = (unique_ln.strip("\t\n")).split("\t")
            for elm in unique_ln_split:
                needs_to_add.append(elm)
                if elm not in set_needs_to_add:
                    set_needs_to_add.append(elm)
        
        ctr = 0
        with open(output_path, "w") as outfile:
            for line in unique_lines[:(N//TP)]:
                ln_split = (line.strip("\t\n")).split("\t")
                for i in range(TP-len(ln_split)):
                    if ctr < len(set_needs_to_add):
                        ln_split.append(set_needs_to_add[ctr])
                        ctr = ctr + 1
                
                write_line = ""
                for elm in ln_split:
                    write_line = write_line + elm + "\t"
                write_line = write_line + "\n"
                outfile.write(write_line)

   


