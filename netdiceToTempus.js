const fs = require('fs')

async function main() {
    const netdiceConfig = JSON.parse(fs.readFileSync("../netdice/eval_sigcomm2020/inputs/mrinfo/with-external/AS-3549-with-external.json").toString())

    const tempusConfig = {
        routers: netdiceConfig.topology.nodes.map((node) => {
            return {
                name: node,
                failProb: 0.0,
                delayModel:{
                    delayType: "Normal", 
                    args: [1, 0]
                }
            }
        }),
        links: netdiceConfig.topology.links.map(link => {
            return {
                u: link.u,
                v: link.v,
                failProb: 0.1,
                delayModel:{
                    delayType: "Normal", 
                    args: [1, 0]
                }
            }
        }),
        fwdTable: {},
        intent: {
            src: "67.17.82.54",
            dst: "67.17.107.10",
            threshold: 2000.0,
            confidenceLevel: 0.995
        }
    }
    
    const tempusConfigString = JSON.stringify(tempusConfig)

    fs.writeFileSync("as-3549.json", tempusConfigString)
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});