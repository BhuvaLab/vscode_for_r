#!/bin/bash --login
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=256G
#SBATCH --job-name=vscc
#SBATCH --time=12:00:00
#SBATCH --qos=normal
#SBATCH --partition=general
#SBATCH --account=a_frazer
#SBATCH -o vscc-%j.output
#SBATCH -e vscc-%j.error
#SBATCH --exclude=bun013

# Parameters to chanage
# --cpus-per-task: logical CPUS/threads -> Requests more phyiscal cores as needed
# --mem: 8 / 16 / 32 / 64 / 128 / 256 / 512 / 1000G subdivs are nice
# --job-name: if u want
# --time: 2:00:00 is 2h, 0:30:00 is 30mins
# --account: Change if ur dharmesh and have ur own sacct

srun --export=PATH,TERM,HOME,LANG --pty /bin/bash -l -c "module load vscode/1.87.0 && code tunnel"
