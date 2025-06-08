import db.Table;
import ghidra.app.script.GhidraScript;
import ghidra.framework.store.db.PackedDBHandle;
import ghidra.framework.store.db.PackedDatabase;
import ghidra.util.task.TaskMonitor;
import java.io.File;
import java.io.IOException;

/* ###
 * IP: GHIDRA
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
// Repack FID database file to eliminate unused blocks and possibly make indices more efficient
//
// The original RepackFid has been modified to work in a headless mode.
//@category FunctionID

public class RepackFidHeadless extends GhidraScript {

  /**
   * Copy a single table between databases
   *
   * @param oldTable  is the old table to copy
   * @param newHandle is the handle to the new database receiving the copy
   * @throws IOException
   */
  private void copyTable(Table oldTable, PackedDBHandle newHandle) throws IOException {
    // Pull out table configuration elements
    var newTable = newHandle.createTable(oldTable.getName(), oldTable.getSchema(),
        oldTable.getIndexedColumns());  // Create new table

    var iterator = oldTable.iterator();
    while (iterator.hasNext()) {
      newTable.putRecord(iterator.next());
    }
  }

  @Override
  protected void run() throws Exception {
    var file = askFile("Select FID database file to repack", "OK");
    var pdb = PackedDatabase.getPackedDatabase(file, false, TaskMonitor.DUMMY);
    var tables = pdb.open(TaskMonitor.DUMMY).getTables();

    var newHandle = new PackedDBHandle(pdb.getContentType());
    for (var table : tables) {
      long transactionID = newHandle.startTransaction();
      copyTable(table, newHandle);
      newHandle.endTransaction(transactionID, true);
    }

    var filePath = file.getAbsolutePath();
    newHandle.saveAs(pdb.getContentType(), file.getParentFile(), file.getName() + ".repacked",
        TaskMonitor.DUMMY);
    newHandle.close();

    file.delete();
    new File(filePath + ".repacked").renameTo(new File(filePath));
  }
}
