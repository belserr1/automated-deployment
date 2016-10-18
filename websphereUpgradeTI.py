import sys;

from socket import gethostname;

hostname = gethostname();

scriptFolder = sys.argv[0];
execfile(scriptFolder + '/wsadminlib.py');

deploymentFolder = sys.argv[1];
tiApp = sys.argv[2];
globalApp = sys.argv[3];
globalServer = sys.argv[4];
tiServer = sys.argv[5];

print "listAllAppServers:", listAllAppServers();

def getWASNodeName() :
  rtn = listAllAppServers()[0][0];
  
  if rtn == "None" :
    rtn = hostname + 'Node01';
    
  return rtn;

nodename = getWASNodeName();
print "nodename: " + nodename;

print "Stopping servers...";

stopAllServers();

print "Deleting applications...";

deleteAllApplications();
save();

print "Installing applications...";

installApplication(deploymentFolder + '/' + globalApp + '.ear', [ { 'nodename' : nodename, 'servername': globalServer }], [], ['-MapWebModToVH', [['.*', '.*', globalServer + '_host']]]);

installApplication(deploymentFolder + '/' + tiApp + '.ear', [ { 'nodename' : nodename, 'servername': tiServer }], [], ['-MapWebModToVH', [['.*', '.*', tiServer + '_host']]]);

setClassloaderToParentLast(globalApp);
setClassloaderToParentLast(tiApp);

AdminTask.modifyJSFImplementation(globalApp, '[-implName "SunRI1.2"]');
AdminTask.modifyJSFImplementation(tiApp, '[-implName "SunRI1.2"]');

save();

print "Starting servers...";

startAllServers();

