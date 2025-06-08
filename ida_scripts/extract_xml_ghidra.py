import ida_ida
import ida_auto
import ida_loader
import ida_hexrays
import ida_idp
import ida_entry
import idaxml

def main():
    print("Waiting for autoanalysis...")
    ida_auto.auto_wait()
    idaxml.XmlExporter(1).export_xml()

main()
