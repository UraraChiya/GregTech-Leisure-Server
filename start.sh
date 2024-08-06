while [ 1 ]
do
    clear
    java -Xms2147483648 -Xmx8589934592 -Djava.awt.headless=true @libraries/net/minecraftforge/forge/1.20.1-47.3.5/unix_args.txt "$@" nogui
    echo 'Restart after 5s'
    echo 'Press Ctrl+C to stop'
    sleep 5
    clear
done