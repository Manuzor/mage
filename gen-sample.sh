
set -e

rootdir="$(pwd)"
[ $(which cygpath) ] && rootdir="$(cygpath -m ${rootdir})"
echo "rootdir: ${rootdir}"

workspace="${rootdir}/workspace"
sample="${1}"
sampledir="${rootdir}/samples/${sample}"

[ -n "${sample}" ] || (echo "No sample name given, e.g. 'sample.sh helloworld'"; exit 1)
[ -d "${sampledir}" ] || (echo "The sample does not exist: ${sampledir}"; exit 1)

function _exec()
{
  echo "executing: $@"
  $@
}

_exec [ -d "${workspace} " ] && rm -rf "${workspace}"
_exec mkdir -p "${workspace}"
_exec cd "${workspace}"
_exec make dist -C "${rootdir}" ${MAKEARGS}
_exec "${rootdir}/output/dist/mage.exe" -Gvs2013 "${sampledir}" ${MAGEARGS}
_exec "${workspace}/wand.exe"
