# Deploy ipset blocklist

Edit hosts file.
Edit vars in deploy.yaml

Then run  

    ansible-playbook -i hosts deploy.yaml --limit server1
