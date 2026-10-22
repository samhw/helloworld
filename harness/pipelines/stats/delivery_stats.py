import os, json, argparse

class StatsCollector:
    _env_obj = None
    _env_stats = None
    _warnings = None

    def __init__(self):
        self._env_stats = {}
        self._env_obj = None
        self._warnings = []

    def getStatsCount(self):
        return len(self._env_stats)

    def readEnv(self):
        return os.environ

    def getStats(self):
        return self._env_stats

    def getJsonStats(self):
        return json.dumps(self._env_stats)

    def getWarnings(self):
        return self._warnings

    def registerEnvStat(self, key_name: str):
        # drop dupes on the floor
        if key_name in self._env_stats:
            msg = "WARN: Key '{}' already registered - dropping on floor".format(key_name)
            self._warnings.append(msg)
            print (msg)
            return

        value = self.lookUp(key_name)
        self._env_stats[key_name] = value.replace("\n", "")
        print("INFO: Registered stat {0} = {1}".format(key_name, value) )

    def registerStat(self, key_name: str, value: str):
        if key_name in self._env_stats:
            msg = "WARN: Key '{}' already registered - dropping on floor".format(key_name)
            self._warnings.append(msg)
            print(msg)
            return

        self._env_stats[key_name] = value
        print("INFO: Registered stat '{0}'='{1}'".format(key_name, value))

    def lookUp(self, key_name: str) -> str:
        # lazy load
        if self._env_obj is None:
            self._env_obj = self.readEnv()

        if not key_name in self._env_obj:
            msg = "WARN: Specified env stat key '{0}' not found in env object".format(key_name)
            self._warnings.append(msg)
            return "???STAT"

        return self._env_obj[key_name]

    def trim(self, key_name: str) -> str:
        if key_name is None or len(key_name) == 0:
            raise ValueError("Attempt to add an env stat with a null or empty key name")

        patchedKey = key_name.strip().replace(" ", "")
        if key_name != patchedKey:
            print ("WARN: Stat key '{0}' patched - new key name is '{1}'".format(key_name, patchedKey) )

        if len(patchedKey) == 0:
            raise ValueError("Attempt to add stat using empty name")

        return patchedKey


######################
### Main interface ###
######################
class Main:
    _collector = None

    def __init__(self):
        self._collector = StatsCollector()

    """Lookup and registers many env stat values from a comma-separated list of key names."""
    def addEnvStats(self, env_keys_names:str):
        if env_keys_names is None or len(env_keys_names) == 0:
            raise ValueError("Attempt to add env stats using empty key name array")

        splits = env_keys_names.split(",")
        for k in splits:
            print ("INFO: Trying to add env stat '{0}'".format(k) )
            self.addEnvStat(k)

    def addEnvStat(self, key_name: str) -> bool:
        """Lookup and registers a single env stat value from the provided key name."""
        if key_name is None or len(key_name) == 0:
            raise ValueError("Attempt to add an env stat with a null or empty key name")

        patchedKey = self._collector.trim(key_name)
        self._collector.registerEnvStat(patchedKey)
        return True

    def addStat(self, key_name:str, value: str) -> bool:
        """Registers a custom stat"""
        if key_name is None or len(key_name) == 0:
            raise ValueError("Attempt to add a stat with a null or empty key name.")

        patchedKey = self._collector.trim(key_name)
        self._collector.registerStat(patchedKey, value)
        return True

    def fetchRawStats(self):
        """Fetches a dictionary of registered stats."""
        return self._collector.getStats()

    def fetchJsonStats(self):
        """Fetches a json representation of registered stats."""
        return self._collector.getJsonStats()

    def fetchWarnings(self):
        """Fetches a list of warnings based."""
        return self._collector.getWarnings()

    def assembleStats(self, parent_name: str) -> str:
        """Assembles a stats json blob for registered stats"""
        if parent_name is None or len(parent_name) == 0:
            raise ValueError("Attempt to assemble stats with null or empty name")

        patched = self._collector.trim(parent_name)

        # flatten dict to list for serializer
        stats = self._collector.getStats()
        rpt = {patched : stats}
        return json.dumps(rpt, sort_keys=True, indent=2)

parser = argparse.ArgumentParser()
parser.add_argument("--statkeys", "-s", help = "Comma-separated list of lookup env keys", default = "")
parser.add_argument("--report", "-r", help = "Stats report name", default = "")
parser.add_argument("--write", "-w", help = "Report file path", default = "")
args = parser.parse_args()

print (args)

main = Main()
if args.statkeys:
    main.addEnvStats(args.statkeys)

if args.report and args.write:
    print ("DEBUG: Calculating report...")
    rpt = main.assembleStats(args.report)
    print ("DEBUG: Stats report")
    print (rpt)
    print ("INFO: Writing file to {}".format(args.write) )
    with open(r"{}".format(args.write), "w" ) as stats:
        stats.write(rpt)
elif args.report:
    print ("DEBUG: Calculating report...")
    rpt = main.assembleStats(args.report)
    print (rpt)
