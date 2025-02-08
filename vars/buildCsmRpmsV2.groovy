/*
 *
 *  MIT License
 *
 *  (C) Copyright 2025 Hewlett Packard Enterprise Development LP
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included
 *  in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 *  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 *  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *  OTHER DEALINGS IN THE SOFTWARE.
 *
 */

/*
 * params: 
 * sourceTarPath (required)
 * specFileBasename (required)
 * outputReldir (required)
 * arch
 */

def call(Map params = [:]) {
    if(!params.sourceTarPath) {
        error("Missing sourceTarPath")
    } else {
        echo "(debug) sourceTarPath=${params.sourceTarPath}"
    }

    if(!params.specFileBasename) {
        error("Missing specFileBasename")
    } else {
        echo "(debug) specFileBasename=${params.specFileBasename}"
    }

    if(!params.outputReldir) {
        error("Missing outputReldir")
    } else {
        echo "(debug) outputReldir=${params.outputReldir}"
    }

    def scriptArgs = []
    echo "(debug) scriptArgs = ${scriptArgs}"
    if(params.arch) {
        echo "(debug) arch=${params.arch}"
        scriptArgs.addAll(["--arch", params.arch])
        echo "(debug) scriptArgs = ${scriptArgs}"
    }

    scriptArgs.addAll([params.outputReldir, params.sourceTarPath, params.specFileBasename])

    echo "scriptArgs = ${scriptArgs}"

    runCMTScript("build_rpm_v2.sh", *scriptArgs)
}
