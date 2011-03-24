/**
 * Created by IntelliJ IDEA.
 * User: James Ward <james@jamesward.org>
 * Date: 3/24/11
 * Time: 12:31 PM
 */
package org.mixingloom.patcher
{
import flash.utils.ByteArray;

import flash.utils.Endian;

import org.as3commons.bytecode.abc.AbcFile;
import org.as3commons.bytecode.abc.InstanceInfo;
import org.as3commons.bytecode.abc.LNamespace;
import org.as3commons.bytecode.abc.MethodBody;
import org.as3commons.bytecode.abc.TraitInfo;
import org.as3commons.bytecode.io.AbcDeserializer;
import org.as3commons.bytecode.io.AbcSerializer;
import org.mixingloom.SwfContext;
import org.mixingloom.SwfTag;
import org.mixingloom.invocation.InvocationType;
import org.mixingloom.utils.HexDump;

public class StringModifierPatcher extends AbstractPatcher {

  public var classTagName:String;
  public var originalString:String;
  public var replacementString:String;

  public function StringModifierPatcher(classTagName:String, originalString:String, replacementString:String)
  {
    this.classTagName = classTagName;
    this.originalString = originalString;
    this.replacementString = replacementString;
  }

  override public function apply( invocationType:InvocationType, swfContext:SwfContext ):void {
    applier.startPatching( this );

    if ( invocationType.type != InvocationType.FRAME2 ) {
      applier.completePatching( this );

      return;
    }

    trace('StringModifierPatcher');
    for each (var swfTag:SwfTag in swfContext.swfTags)
    {
      if (swfTag.name == classTagName)
      {
        trace('found ' + classTagName);

        var searchByteArray:ByteArray = new ByteArray();
        searchByteArray.writeUTFBytes(originalString);
        searchByteArray.position = 0;

        var modifiedTagBody:ByteArray = new ByteArray();
        modifiedTagBody.endian = Endian.LITTLE_ENDIAN;

        swfTag.tagBody.position = 0;

        for (var i:uint = 0; i < (swfTag.tagBody.length - searchByteArray.length - 1); i++)
        {
          swfTag.tagBody.position = i;
          
          var testByteArray:ByteArray = new ByteArray();
          swfTag.tagBody.readBytes(testByteArray, 0, searchByteArray.length);

          var stringNotFound:Boolean = false;

          searchByteArray.position = 0;
          testByteArray.position = 0;
          for (var j:uint = 0; j < searchByteArray.length; j++)
          {
            if (searchByteArray.readByte() != testByteArray.readByte())
            {
              stringNotFound = true;
              break;
            }
          }

          if (stringNotFound)
          {
            swfTag.tagBody.position = i;
            modifiedTagBody.writeByte(swfTag.tagBody.readByte());
          }
          else
          {
            trace('found!!! ' + i);

            modifiedTagBody.writeUTFBytes(replacementString);
            i += searchByteArray.length - 1;
            trace(i);
          }

        }

        // write the last searchByteArray.length bytes to the end of the modifiedTagBody
        modifiedTagBody.writeBytes(swfTag.tagBody, (swfTag.tagBody.length - searchByteArray.length - 1));

        swfTag.tagBody.position = 0;
        trace(HexDump.dumpHex(swfTag.tagBody));

        modifiedTagBody.position = 0;
        trace(HexDump.dumpHex(modifiedTagBody));

        swfTag.tagBody = modifiedTagBody;

        trace('tag length = ' + swfTag.tagBody.length);

        swfTag.recordHeader = new ByteArray();
        swfTag.recordHeader.endian = Endian.LITTLE_ENDIAN;
        swfTag.recordHeader.writeByte(0xbf);
        swfTag.recordHeader.writeByte(0x14);
        swfTag.recordHeader.writeInt(swfTag.tagBody.length);

        swfTag.modified = true;
      }
    }

    applier.completePatching( this );
  }

}
}
