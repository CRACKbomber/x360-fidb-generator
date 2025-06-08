import ghidra.app.script.GhidraScript;
import ghidra.feature.fid.db.FidFileManager;
import java.io.File;

public class CreateEmptyFidDatabase extends GhidraScript {

  @Override
  protected void run() throws Exception {
    var fidPath = askString("Enter name of FidDB file", "OK");
    var f = new File(fidPath);

    FidFileManager.getInstance().createNewFidDatabase(f);
    FidFileManager.getInstance().addUserFidFile(f);
  }
}
